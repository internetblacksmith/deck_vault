class CardSetsController < ApplicationController
  before_action :set_card_set, only: [ :show, :update_card, :destroy, :retry_images, :refresh_cards, :update_binder_settings, :import_csv ]

  rescue_from ActiveRecord::RecordNotFound do |e|
    respond_to do |format|
      format.json { render json: { success: false, error: "Record not found" }, status: :not_found }
      format.html { render file: Rails.root.join("public/404.html"), status: :not_found, layout: false }
    end
  end

  def index
    # Pre-load downloaded sets with all related data (fast, from local DB)
    # Include cards and their collection_cards for owned_cards_count calculation
    @downloaded_sets = CardSet.includes(cards: :collection_card)

    # Create a map for O(1) lookups by code
    @downloaded_sets_map = @downloaded_sets.index_by(&:code)

    # Available sets are now loaded async via JavaScript
  end

  def available_sets
    # Fetch all sets from Scryfall and group by parent
    all_sets = ScryfallService.fetch_sets
    grouped_sets = ScryfallService.group_sets(all_sets)

    # Get downloaded set codes for status
    downloaded_codes = CardSet.pluck(:code, :id).to_h

    # Add download status to each set
    sets_with_status = grouped_sets.map do |set_group|
      downloaded = downloaded_codes[set_group[:code]]
      {
        **set_group,
        downloaded: downloaded.present?,
        downloaded_id: downloaded,
        children: set_group[:children].map do |child|
          child_downloaded = downloaded_codes[child[:code]]
          {
            **child,
            downloaded: child_downloaded.present?,
            downloaded_id: child_downloaded
          }
        end
      }
    end

    render json: sets_with_status
  end

  def show
    @view_type = params[:view_type] || "table"

    # Load child sets (subsets) for this set
    @child_sets = @card_set.child_sets.includes(cards: :collection_card).order(:name)

    # For binder view, use saved setting; for other views, use URL parameter
    if @view_type == "binder"
      @include_subsets = @card_set.include_subsets?
    else
      @include_subsets = params[:include_subsets] == "true"
    end

    # Group by set toggle (defaults to true when including subsets in grid/table view)
    @group_by_set = if params[:group_by_set].present?
                      params[:group_by_set] == "true"
    else
                      @include_subsets && %w[grid table].include?(@view_type)
    end

    # Include cards from child sets if requested (for any view type)
    if @include_subsets && @child_sets.any?
      # Get all set IDs (parent + children)
      all_set_ids = [ @card_set.id ] + @child_sets.map(&:id)

      # Load all cards from parent and child sets, grouped by set
      @cards = Card.includes(:collection_card, :card_set)
                   .where(card_set_id: all_set_ids)
                   .order(Arel.sql("card_set_id, CAST(SUBSTR(collector_number, 1, LENGTH(collector_number) - LENGTH(LTRIM(collector_number, '0123456789'))) AS INTEGER), collector_number"))

      # Group cards by their set for display (only if group_by_set is enabled)
      @cards_by_set = @group_by_set ? @cards.group_by(&:card_set) : nil
    else
      # Pre-load cards with collection card data, sorted by collector number
      @cards = @card_set.cards.includes(:collection_card).order(
        Arel.sql("CAST(SUBSTR(collector_number, 1, LENGTH(collector_number) - LENGTH(LTRIM(collector_number, '0123456789'))) AS INTEGER), collector_number")
      )
      @cards_by_set = nil
    end
  end

  def download_set
    set_code = params[:set_code]

    # Check how many child sets exist before download
    child_codes = ScryfallService.fetch_child_sets(set_code)

    # Start download (includes children by default)
    card_set = ScryfallService.download_set(set_code)

    if card_set
      card_set.update(download_status: :downloading)

      message = "Set download started!"
      message += " Including #{child_codes.count} related sets." if child_codes.any?
      message += " Images will be downloaded in the background..."

      redirect_to card_set_path(card_set), notice: message
    else
      redirect_to card_sets_path, alert: "Failed to download set"
    end
  end

  def update_card
    card = @card_set.cards.find(params[:card_id])
    collection_card = card.collection_card || CollectionCard.new(card: card)

    quantity = params[:quantity].to_i
    foil_quantity = params[:foil_quantity].to_i

    collection_card.quantity = quantity
    collection_card.foil_quantity = foil_quantity
    collection_card.notes = params[:notes]

    if collection_card.save
      # Broadcast via Turbo Streams for real-time updates
      # The partial determines what gets rendered based on view type
      render turbo_stream: turbo_stream.replace("card-row-#{card.id}",
        partial: "card_sets/card_row", locals: { card: card, view_type: @view_type || "table", card_set: @card_set })
    else
      render turbo_stream: turbo_stream.replace("card-row-#{card.id}",
        partial: "card_sets/error", locals: { errors: collection_card.errors }), status: :unprocessable_entity
    end
   rescue ActiveRecord::RecordNotFound
     render turbo_stream: turbo_stream.replace("card-row-#{params[:card_id]}",
       partial: "card_sets/error", locals: { errors: "Card not found" }), status: :not_found
   end

  def destroy
    set_name = @card_set.name
    # Eager load cards and collection_cards to avoid strict loading violation when dependent: :destroy runs
    card_set = CardSet.includes(cards: :collection_card).find(@card_set.id)
    card_set.destroy

    respond_to do |format|
      format.json { render json: { success: true, message: "#{set_name} has been deleted" } }
      format.html { redirect_to card_sets_path, notice: "#{set_name} has been deleted" }
    end
  end

  def retry_images
    # Re-fetch card data from Scryfall and update image_uris for cards missing images
    cards_without_images = @card_set.cards.where(image_path: nil)
    count = cards_without_images.count

    if count == 0
      respond_to do |format|
        format.json { render json: { success: true, message: "All images already downloaded" } }
        format.html { redirect_to card_set_path(@card_set), notice: "All images already downloaded" }
      end
      return
    end

    # Update card image_uris from Scryfall and queue download jobs
    cards_without_images.each do |card|
      # Refresh image_uris from Scryfall API (handles DFCs correctly now)
      response = HTTParty.get("https://api.scryfall.com/cards/#{card.scryfall_id}")
      if response.success?
        image_uris = ScryfallService.extract_image_uris(response.parsed_response)
        card.update(image_uris: image_uris.to_json) if image_uris
      end

      # Queue download job
      DownloadCardImagesJob.perform_later(card.id)
    end

    @card_set.update(download_status: :downloading)

    respond_to do |format|
      format.json { render json: { success: true, message: "Retrying download for #{count} images" } }
      format.html { redirect_to card_set_path(@card_set), notice: "Retrying download for #{count} images..." }
    end
  end

  def refresh_cards
    result = ScryfallService.refresh_set(@card_set)

    if result[:error]
      message = "Refresh failed: #{result[:error]}"
      respond_to do |format|
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
        format.html { redirect_to card_set_path(@card_set), alert: message }
      end
    else
      message = "Refresh complete: #{result[:added]} new cards added"
      message += ", #{result[:updated]} cards updated" if result[:updated] > 0

      respond_to do |format|
        format.json { render json: { success: true, added: result[:added], updated: result[:updated], message: message } }
        format.html { redirect_to card_set_path(@card_set), notice: message }
      end
    end
  end

  def update_binder_settings
    if @card_set.update(binder_settings_params)
      respond_to do |format|
        format.json { render json: { success: true, message: "Binder settings saved" } }
        format.html { redirect_to card_set_path(@card_set, view_type: "binder"), notice: "Binder settings saved" }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @card_set.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to card_set_path(@card_set, view_type: "binder"), alert: "Failed to save binder settings" }
      end
    end
  end

  def import_csv
    unless params[:csv_file].present?
      redirect_to card_set_path(@card_set), alert: "Please select a CSV file to import"
      return
    end

    csv_content = params[:csv_file].read
    result = CsvImportService.new(@card_set, csv_content).import

    if result.success
      message = "Imported #{result.imported.count} cards"
      message += ", skipped #{result.skipped.count}" if result.skipped.any?
      redirect_to card_set_path(@card_set), notice: message
    else
      error_msg = "Import failed: #{result.errors.first(3).join(', ')}"
      error_msg += "..." if result.errors.count > 3
      redirect_to card_set_path(@card_set), alert: error_msg
    end
  end

  def export_collection
    # Export all collection cards with quantities > 0
    collection_data = CollectionCard
      .where("quantity > 0 OR foil_quantity > 0")
      .pluck(:card_id, :quantity, :foil_quantity)
      .map { |card_id, qty, foil_qty| { card_id: card_id, quantity: qty || 0, foil_quantity: foil_qty || 0 } }

    export = {
      version: 1,
      exported_at: Time.current.iso8601,
      total_cards: collection_data.size,
      collection: collection_data
    }

    send_data export.to_json,
      filename: "mtg_collection_#{Date.current}.json",
      type: "application/json",
      disposition: "attachment"
  end

  def import_collection
    files = params[:backup_files]
    files ||= params[:backup_file] ? [ params[:backup_file] ] : []

    if files.empty?
      redirect_to card_sets_path, alert: "Please select at least one backup file to import"
      return
    end

    total_imported = 0
    total_skipped = 0
    all_errors = []

    files.each do |file|
      begin
        backup_data = JSON.parse(file.read)
        collection = backup_data["collection"]

        unless collection.is_a?(Array)
          all_errors << "#{file.original_filename}: Invalid backup file format"
          next
        end

        imported = 0
        skipped = 0

        collection.each do |item|
          card_id = item["card_id"]
          quantity = item["quantity"].to_i
          foil_quantity = item["foil_quantity"].to_i

          # Skip if card doesn't exist in database
          # Must preload card_set to avoid strict loading violation when touch: true triggers
          card = Card.includes(:card_set).find_by(id: card_id)
          unless card
            skipped += 1
            next
          end

          # Find or create collection card and update quantities
          collection_card = CollectionCard.find_or_initialize_by(card_id: card_id)
          collection_card.card = card  # Assign preloaded card for touch callback chain
          collection_card.quantity = quantity
          collection_card.foil_quantity = foil_quantity

          if collection_card.save
            imported += 1
          else
            skipped += 1
          end
        end

        total_imported += imported
        total_skipped += skipped

      rescue JSON::ParserError
        all_errors << "#{file.original_filename}: Invalid JSON file"
      rescue StandardError => e
        Rails.logger.error("Collection import error: #{e.message}")
        all_errors << "#{file.original_filename}: #{e.message}"
      end
    end

    if total_imported > 0
      message = "Restored #{total_imported} cards"
      message += ", skipped #{total_skipped} (cards not in database)" if total_skipped > 0
      redirect_to card_sets_path, notice: message
    elsif all_errors.any?
      error_msg = "Import failed: #{all_errors.first(3).join('; ')}"
      error_msg += "..." if all_errors.count > 3
      redirect_to card_sets_path, alert: error_msg
    else
      redirect_to card_sets_path, alert: "No valid backup files provided"
    end
  end

  # Export full collection data for static showcase site
  # Includes all card details, set info, and image URLs
  def export_showcase
    sets = CardSet.includes(cards: :collection_card).order(:name)

    sets_data = sets.map do |card_set|
      owned_cards = card_set.cards.select { |c| c.collection_card&.quantity.to_i > 0 || c.collection_card&.foil_quantity.to_i > 0 }
      {
        code: card_set.code,
        name: card_set.name,
        released_at: card_set.released_at,
        card_count: card_set.cards.count,
        owned_count: owned_cards.count,
        completion_percentage: card_set.cards.count > 0 ? (owned_cards.count.to_f / card_set.cards.count * 100).round(1) : 0
      }
    end

    cards_data = Card.includes(:card_set, :collection_card)
                     .joins(:collection_card)
                     .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                     .map { |card| format_card_for_export(card) }

    total_cards = cards_data.sum { |c| c[:quantity] + c[:foil_quantity] }

    export = {
      version: 2,
      export_type: "showcase",
      exported_at: Time.current.iso8601,
      stats: {
        total_unique: cards_data.count,
        total_cards: total_cards,
        total_foils: cards_data.sum { |c| c[:foil_quantity] },
        sets_collected: sets_data.count { |s| s[:owned_count] > 0 }
      },
      sets: sets_data.select { |s| s[:owned_count] > 0 },
      cards: cards_data
    }

    send_data export.to_json,
      filename: "mtg_showcase_#{Date.current}.json",
      type: "application/json",
      disposition: "attachment"
  end

  # Export only duplicate cards (quantity > 1) for selling
  def export_duplicates
    duplicates = Card.includes(:card_set, :collection_card)
                     .joins(:collection_card)
                     .where("collection_cards.quantity > 1 OR collection_cards.foil_quantity > 1")
                     .map { |card| format_card_for_export(card, duplicates_only: true) }
                     .select { |c| c[:duplicate_quantity] > 0 || c[:duplicate_foil_quantity] > 0 }

    total_duplicates = duplicates.sum { |c| c[:duplicate_quantity] + c[:duplicate_foil_quantity] }

    export = {
      version: 1,
      export_type: "duplicates",
      exported_at: Time.current.iso8601,
      stats: {
        unique_cards_with_duplicates: duplicates.count,
        total_duplicate_cards: total_duplicates,
        total_duplicate_foils: duplicates.sum { |c| c[:duplicate_foil_quantity] }
      },
      cards: duplicates
    }

    send_data export.to_json,
      filename: "mtg_duplicates_#{Date.current}.json",
      type: "application/json",
      disposition: "attachment"
  end

  # Import collection from Delver Lens .dlens backup file (SQLite format)
  # Note: This often fails because .dlens files don't contain Scryfall IDs
  # Recommend using import_delver_csv instead
  def import_delver
    unless params[:dlens_file].present?
      redirect_to card_sets_path, alert: "Please select a .dlens backup file to import"
      return
    end

    file = params[:dlens_file]

    # Validate file extension
    unless file.original_filename.end_with?(".dlens")
      redirect_to card_sets_path, alert: "Please upload a .dlens file (Delver Lens backup)"
      return
    end

    result = DelverImportService.new(file).import

    if result.success?
      message = "Imported #{result.imported} cards (#{result.foils_imported} foils)"
      message += ", skipped #{result.skipped} (not found in database)" if result.skipped > 0
      redirect_to card_sets_path, notice: message
    else
      error_msg = "Import failed: #{result.errors.first(3).join(', ')}"
      error_msg += "..." if result.errors.count > 3
      redirect_to card_sets_path, alert: error_msg
    end
  end

  # Publish collection to GitHub Gist for Showcase site
  def publish_to_gist
    result = GistExportService.new.export

    respond_to do |format|
      if result[:success]
        format.json { render json: result }
        format.html { redirect_to card_sets_path, notice: result[:message] }
      else
        format.json { render json: result, status: :unprocessable_entity }
        format.html { redirect_to card_sets_path, alert: result[:error] }
      end
    end
  end

  # Import collection from Delver Lens CSV export
  # This is the recommended method as CSV exports include Scryfall IDs
  # Supports multiple files at once
  def import_delver_csv
    files = params[:csv_files]
    files ||= params[:csv_file] ? [ params[:csv_file] ] : []

    if files.empty?
      redirect_to card_sets_path, alert: "Please select at least one CSV file to import"
      return
    end

    mode = params[:import_mode]&.to_sym || :add
    total_imported = 0
    total_foils_imported = 0
    total_skipped = 0
    all_errors = []
    all_downloaded_sets = []
    all_missing_sets = Set.new

    files.each do |file|
      # Validate file extension
      unless file.original_filename.end_with?(".csv")
        all_errors << "#{file.original_filename}: Please upload CSV files only"
        next
      end

      begin
        csv_content = file.read.force_encoding("UTF-8")
        result = DelverCsvImportService.new(csv_content, mode: mode).import

        if result.success?
          total_imported += result.imported
          total_foils_imported += result.foils_imported
          total_skipped += result.skipped
          all_downloaded_sets.concat(result.downloaded_sets)
          all_missing_sets.merge(result.missing_sets)
        else
          all_errors.concat(result.errors)
        end
      rescue StandardError => e
        all_errors << "#{file.original_filename}: #{e.message}"
      end
    end

    if total_imported > 0 || total_foils_imported > 0 || total_skipped > 0
      mode_text = mode == :replace ? "Replaced with" : "Added"
      message = "#{mode_text} #{total_imported} cards"
      message += " (#{total_foils_imported} foils)" if total_foils_imported > 0
      message += ", skipped #{total_skipped}" if total_skipped > 0

      if all_downloaded_sets.any?
        set_names = all_downloaded_sets.map { |s| s[:name] }.uniq
        message += ". Downloaded #{set_names.count} set(s): #{set_names.first(3).join(', ')}"
        message += "..." if set_names.count > 3
      end

      if all_missing_sets.any?
        message += ". Could not find sets: #{all_missing_sets.to_a.first(3).join(', ')}"
        message += "..." if all_missing_sets.count > 3
      end

      redirect_to card_sets_path, notice: message
    elsif all_errors.any?
      error_msg = "Import failed: #{all_errors.first(3).join('; ')}"
      error_msg += "..." if all_errors.count > 3
      redirect_to card_sets_path, alert: error_msg
    else
      redirect_to card_sets_path, alert: "No valid CSV files provided"
    end
  end

  private

  def format_card_for_export(card, duplicates_only: false)
    quantity = card.collection_card&.quantity.to_i
    foil_quantity = card.collection_card&.foil_quantity.to_i
    image_uris = JSON.parse(card.image_uris || "{}")
    back_image_uris = card.back_image_uris.present? ? JSON.parse(card.back_image_uris) : nil

    data = {
      id: card.id,
      name: card.name,
      set_code: card.card_set.code,
      set_name: card.card_set.name,
      collector_number: card.collector_number,
      rarity: card.rarity,
      type_line: card.type_line,
      mana_cost: card.mana_cost,
      image_url: image_uris["normal"] || image_uris["large"],
      image_url_small: image_uris["small"],
      back_image_url: back_image_uris&.dig("normal") || back_image_uris&.dig("large"),
      is_foil_available: card.foil,
      is_nonfoil_available: card.nonfoil,
      quantity: quantity,
      foil_quantity: foil_quantity
    }

    if duplicates_only
      # For duplicates export, calculate how many are available to sell (keep 1 of each)
      data[:duplicate_quantity] = [ quantity - 1, 0 ].max
      data[:duplicate_foil_quantity] = [ foil_quantity - 1, 0 ].max
    end

    data
  end

  def binder_settings_params
     params.permit(:binder_rows, :binder_columns, :binder_sort_field, :binder_sort_direction, :include_subsets, :binder_pages_per_binder)
   end

   def set_card_set
     @card_set = CardSet.find(params[:id])
   end
end
