class CardSetsController < ApplicationController
  before_action :set_card_set, only: [ :show, :update_card ]

  def index
    # Fetch all sets from Scryfall
    @available_sets = ScryfallService.fetch_sets

    # Pre-load downloaded sets with all related data
    @downloaded_sets = CardSet.includes(:cards)

    # Create a map for O(1) lookups by code
    @downloaded_sets_map = @downloaded_sets.index_by(&:code)
  end

  def show
    # Pre-load cards with collection card data
    @cards = @card_set.cards.includes(:collection_card)
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
    page_number = params[:page_number].presence ? params[:page_number].to_i : nil

    collection_card.quantity = quantity
    collection_card.page_number = page_number
    collection_card.notes = params[:notes]

    if collection_card.save
      render json: { success: true, collection_card: collection_card }
    else
      render json: { success: false, errors: collection_card.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, errors: "Card not found" }, status: :not_found
  end

  private

  def set_card_set
    @card_set = CardSet.find(params[:id])
  end
end
