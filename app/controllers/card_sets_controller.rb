class CardSetsController < ApplicationController
  before_action :set_card_set, only: [ :show, :update_card, :destroy, :retry_images, :update_binder_settings ]

  rescue_from ActiveRecord::RecordNotFound do |e|
    respond_to do |format|
      format.json { render json: { success: false, error: "Record not found" }, status: :not_found }
      format.html { render file: Rails.root.join("public/404.html"), status: :not_found, layout: false }
    end
  end

  def index
    # Pre-load downloaded sets with all related data (fast, from local DB)
    @downloaded_sets = CardSet.includes(:cards)

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
    # Pre-load cards with collection card data, sorted by collector number
    # Use SQL sorting that matches the JS sortable_collector_number logic:
    # - Extract numeric part and pad it, then append any suffix
    @cards = @card_set.cards.includes(:collection_card).order(
      Arel.sql("CAST(SUBSTR(collector_number, 1, LENGTH(collector_number) - LENGTH(LTRIM(collector_number, '0123456789'))) AS INTEGER), collector_number")
    )
    @view_type = params[:view_type] || "table"
  end

  def download_set
    set_code = params[:set_code]

    # Start download in background
    card_set = ScryfallService.download_set(set_code)

    if card_set
      card_set.update(download_status: :downloading)
      redirect_to card_set_path(card_set), notice: "Set download started! Images will be downloaded in the background..."
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

   private

   def binder_settings_params
     params.permit(:binder_rows, :binder_columns, :binder_sort_field, :binder_sort_direction)
   end

   def set_card_set
     @card_set = CardSet.find(params[:id])
   end
end
