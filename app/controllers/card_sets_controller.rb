class CardSetsController < ApplicationController
  before_action :set_card_set, only: [ :show, :update_card ]

  def index
    # Fetch all sets from Scryfall
    @available_sets = ScryfallService.fetch_sets
    @downloaded_sets = CardSet.all
  end

  def show
    @cards = @card_set.cards
    @view_type = params[:view_type] || "table"
  end

  def download_set
    set_code = params[:set_code]
    card_set = ScryfallService.download_set(set_code)

    if card_set
      redirect_to card_set_path(card_set), notice: "Set downloaded successfully!"
    else
      redirect_to card_sets_path, alert: "Failed to download set"
    end
  end

  def update_card
    card = @card_set.cards.find(params[:card_id])
    collection_card = card.collection_card || CollectionCard.new(card: card)

    collection_card.quantity = params[:quantity].to_i
    collection_card.page_number = params[:page_number].to_i
    collection_card.notes = params[:notes]

    if collection_card.save
      render json: { success: true, collection_card: collection_card }
    else
      render json: { success: false, errors: collection_card.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_card_set
    @card_set = CardSet.find(params[:id])
  end
end
