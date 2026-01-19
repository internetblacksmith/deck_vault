# frozen_string_literal: true

class CardSetsController < ApplicationController
  before_action :set_card_set, only: [ :show, :update_card, :destroy, :retry_images, :refresh_cards, :update_binder_settings, :import_csv, :download_card_image, :clear_placement_markers ]

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

    # Load child sets (subsets) for this set with eager-loaded cards
    @child_sets = @card_set.child_sets.includes(cards: :collection_card).order(:name)

    # Preload main set cards for stats (reuse later, avoids duplicate queries in view)
    @main_set_cards = @card_set.cards.includes(:collection_card).to_a

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

    # Preload child set cards for stats (use already eager-loaded data)
    @child_sets_with_cards = @child_sets.map do |cs|
      { card_set: cs, cards: cs.cards.to_a }
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

    # Handle clearing needs_placement marker
    if params[:clear_needs_placement] == true || params[:clear_needs_placement] == "true"
      collection_card.needs_placement_at = nil
      if collection_card.save
        respond_to do |format|
          format.json { render json: { success: true } }
          format.html { redirect_to card_set_path(@card_set) }
        end
      else
        respond_to do |format|
          format.json { render json: { success: false, errors: collection_card.errors.full_messages }, status: :unprocessable_entity }
        end
      end
      return
    end

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
      message += ", #{result[:images_queued]} images queued for download" if result[:images_queued] > 0

      respond_to do |format|
        format.json { render json: { success: true, added: result[:added], updated: result[:updated], images_queued: result[:images_queued], message: message } }
        format.html { redirect_to card_set_path(@card_set), notice: message }
      end
    end
  end

  def download_card_image
    card_id = params[:card_id]
    card = @card_set.cards.find_by(id: card_id)

    unless card
      respond_to do |format|
        format.json { render json: { success: false, error: "Card not found" }, status: :not_found }
      end
      return
    end

    if card.image_path.present?
      respond_to do |format|
        format.json { render json: { success: true, message: "Image already downloaded", image_path: card.image_path } }
      end
      return
    end

    # Refresh image_uris from Scryfall API first (in case they changed)
    response = HTTParty.get("https://api.scryfall.com/cards/#{card.scryfall_id}")
    if response.success?
      front_uris, back_uris = ScryfallService.extract_image_uris(response.parsed_response)
      # Update both in a single transaction
      card.update(
        image_uris: front_uris.present? ? front_uris.to_json : card.image_uris,
        back_image_uris: back_uris.present? ? back_uris.to_json : card.back_image_uris
      )
    end

    # Queue the download job with a small delay to avoid SQLite race condition
    # This ensures the transaction is fully committed before Sidekiq picks it up
    DownloadCardImagesJob.set(wait: 1.second).perform_later(card.id)

    respond_to do |format|
      format.json { render json: { success: true, message: "Image download queued for #{card.name}" } }
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

  def clear_placement_markers
    # Get all card IDs for this set (and child sets if include_subsets)
    card_ids = @card_set.cards.pluck(:id)

    if @card_set.include_subsets?
      child_card_ids = @card_set.child_sets.joins(:cards).pluck("cards.id")
      card_ids += child_card_ids
    end

    # Clear all needs_placement markers for these cards
    count = CollectionCard.where(card_id: card_ids)
                          .where.not(needs_placement_at: nil)
                          .update_all(needs_placement_at: nil)

    respond_to do |format|
      format.json { render json: { success: true, cleared: count } }
      format.html { redirect_to card_set_path(@card_set, view_type: "binder"), notice: "Cleared #{count} placement markers" }
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

  private

  def binder_settings_params
    params.permit(:binder_rows, :binder_columns, :binder_sort_field, :binder_sort_direction, :include_subsets, :binder_pages_per_binder)
  end

  def set_card_set
    @card_set = CardSet.find(params[:id])
  end
end
