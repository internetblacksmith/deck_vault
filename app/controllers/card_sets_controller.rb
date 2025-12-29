class CardSetsController < ApplicationController
  before_action :set_card_set, only: [ :show, :update_card ]
  before_action :set_cache_headers, only: [ :show ]

  def index
    # Fetch all sets from Scryfall
    @available_sets = ScryfallService.fetch_sets

    # Pre-load downloaded sets with all related data
    @downloaded_sets = CardSet.includes(:cards)

    # Create a map for O(1) lookups by code
    @downloaded_sets_map = @downloaded_sets.index_by(&:code)

    # Set cache headers for index page
    # Cache for 1 hour since sets don't change often
    expires_in 1.hour, public: true
  end

  def show
    # Pre-load cards with collection card data
    @cards = @card_set.cards.includes(:collection_card)
    @view_type = params[:view_type] || "table"

    # Set ETag for conditional requests
    # Cache is invalidated when card_set is updated (via touch: true in associations)
    # Collection cards touching their card model propagates to card_set
    fresh_when(@card_set)
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
    page_number = params[:page_number].presence ? params[:page_number].to_i : nil

    collection_card.quantity = quantity
    collection_card.page_number = page_number
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

   private

   def set_card_set
     @card_set = CardSet.find(params[:id])
   end

   def set_cache_headers
     # For completed sets, cache aggressively since they don't change
     # For downloading/pending sets, don't cache to show real-time progress
     if @card_set.completed?
       expires_in 24.hours, public: true
     elsif @card_set.downloading? || @card_set.pending?
       # Don't cache while downloading to ensure progress shows real-time
       expires_in 0.seconds, public: false
     else
       # Default cache for 1 hour for other states
       expires_in 1.hour, public: true
     end
   end
end
