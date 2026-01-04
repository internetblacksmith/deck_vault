# frozen_string_literal: true

module Api
  module V1
    class SetsController < BaseController
      def index
        sets = CardSet.where(download_status: :completed).order(:name)

        render json: {
          sets: sets.map { |set| format_set(set) }
        }
      end

      def show
        set = CardSet.find_by!(code: params[:id].downcase)
        cards = set.cards.includes(:collection_card).order(:collector_number)

        render json: {
          set: format_set(set),
          cards: cards.map { |card| format_card(card) }
        }
      end

      def download
        set_code = params[:set_code]&.downcase

        unless set_code.present?
          render json: { error: "set_code is required" }, status: :unprocessable_entity
          return
        end

        # Check if already downloaded
        existing = CardSet.find_by(code: set_code)
        if existing&.completed?
          render json: { message: "Set already downloaded", set: format_set(existing) }
          return
        end

        # Download from Scryfall
        card_set = ScryfallService.download_set(set_code, include_children: false)

        if card_set
          render json: {
            message: "Set download started",
            set: format_set(card_set)
          }
        else
          render json: { error: "Failed to download set from Scryfall" }, status: :unprocessable_entity
        end
      end

      private

      def format_set(set)
        owned_count = set.cards.joins(:collection_card)
                         .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                         .count
        {
          code: set.code,
          name: set.name,
          released_at: set.released_at,
          set_type: set.set_type,
          card_count: set.cards.count,
          owned_count: owned_count,
          completion_percentage: set.cards.count > 0 ? (owned_count.to_f / set.cards.count * 100).round(1) : 0,
          download_status: set.download_status
        }
      end

      def format_card(card)
        collection = card.collection_card
        {
          id: card.id,
          name: card.name,
          collector_number: card.collector_number,
          rarity: card.rarity,
          type_line: card.type_line,
          mana_cost: card.mana_cost,
          quantity: collection&.quantity.to_i,
          foil_quantity: collection&.foil_quantity.to_i,
          owned: (collection&.quantity.to_i || 0) > 0 || (collection&.foil_quantity.to_i || 0) > 0
        }
      end
    end
  end
end
