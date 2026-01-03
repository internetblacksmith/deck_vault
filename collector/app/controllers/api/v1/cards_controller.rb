# frozen_string_literal: true

module Api
  module V1
    class CardsController < BaseController
      def index
        cards = Card.includes(:collection_card, :card_set)

        # Filter by set
        if params[:set].present?
          cards = cards.joins(:card_set).where(card_sets: { code: params[:set].downcase })
        end

        # Filter by search query
        if params[:q].present?
          search_term = "%#{params[:q]}%"
          cards = cards.where("cards.name LIKE ?", search_term)
        end

        # Filter by rarity
        if params[:rarity].present?
          cards = cards.where(rarity: params[:rarity].downcase)
        end

        # Filter owned/missing
        if params[:owned] == "true"
          cards = cards.joins(:collection_card)
                       .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
        elsif params[:missing] == "true"
          cards = cards.left_joins(:collection_card)
                       .where("collection_cards.id IS NULL OR (collection_cards.quantity = 0 AND collection_cards.foil_quantity = 0)")
        end

        # Limit results
        limit = [ params[:limit]&.to_i || 100, 500 ].min
        cards = cards.limit(limit)

        render json: {
          count: cards.count,
          cards: cards.map { |card| format_card(card) }
        }
      end

      def show
        card = Card.includes(:collection_card, :card_set).find(params[:id])
        render json: { card: format_card_full(card) }
      end

  def update
    card = Card.includes(:collection_card, :card_set).find(params[:id])
    collection = card.collection_card || CollectionCard.new(card: card)

        collection.quantity = params[:quantity].to_i if params[:quantity].present?
        collection.foil_quantity = params[:foil_quantity].to_i if params[:foil_quantity].present?

        if collection.save
          render json: {
            message: "Card updated",
            card: format_card_full(card.reload)
          }
        else
          render json: { error: collection.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def format_card(card)
        collection = card.collection_card
        {
          id: card.id,
          name: card.name,
          set_code: card.card_set.code,
          set_name: card.card_set.name,
          collector_number: card.collector_number,
          rarity: card.rarity,
          type_line: card.type_line,
          mana_cost: card.mana_cost,
          quantity: collection&.quantity.to_i,
          foil_quantity: collection&.foil_quantity.to_i,
          owned: (collection&.quantity.to_i || 0) > 0 || (collection&.foil_quantity.to_i || 0) > 0
        }
      end

      def format_card_full(card)
        collection = card.collection_card
        image_uris = JSON.parse(card.image_uris || "{}")

        {
          id: card.id,
          name: card.name,
          set_code: card.card_set.code,
          set_name: card.card_set.name,
          collector_number: card.collector_number,
          rarity: card.rarity,
          type_line: card.type_line,
          mana_cost: card.mana_cost,
          oracle_text: card.oracle_text,
          image_url: image_uris["normal"] || image_uris["large"],
          quantity: collection&.quantity.to_i,
          foil_quantity: collection&.foil_quantity.to_i,
          owned: (collection&.quantity.to_i || 0) > 0 || (collection&.foil_quantity.to_i || 0) > 0,
          foil_available: card.foil,
          nonfoil_available: card.nonfoil
        }
      end
    end
  end
end
