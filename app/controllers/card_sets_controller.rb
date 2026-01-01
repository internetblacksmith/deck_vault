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
    unless params[:backup_file].present?
      redirect_to card_sets_path, alert: "Please select a backup file to import"
      return
    end

    begin
      backup_data = JSON.parse(params[:backup_file].read)
      collection = backup_data["collection"]

      unless collection.is_a?(Array)
        redirect_to card_sets_path, alert: "Invalid backup file format"
        return
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

      message = "Restored #{imported} cards"
      message += ", skipped #{skipped} (cards not in database)" if skipped > 0
      redirect_to card_sets_path, notice: message

    rescue JSON::ParserError
      redirect_to card_sets_path, alert: "Invalid JSON file"
    rescue StandardError => e
      Rails.logger.error("Collection import error: #{e.message}")
      redirect_to card_sets_path, alert: "Import failed: #{e.message}"
    end
  end

   private

   def binder_settings_params
     params.permit(:binder_rows, :binder_columns, :binder_sort_field, :binder_sort_direction, :include_subsets)
   end

   def set_card_set
     @card_set = CardSet.find(params[:id])
   end
end
