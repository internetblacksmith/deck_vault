# frozen_string_literal: true

module Api
  module V1
    class StatsController < BaseController
      def index
        sets = CardSet.where(download_status: :completed)
        total_cards = sets.sum { |s| s.cards.count }
        owned_cards = CollectionCard.sum(:quantity).to_i + CollectionCard.sum(:foil_quantity).to_i
        unique_owned = CollectionCard.where("quantity > 0 OR foil_quantity > 0").count

        render json: {
          sets_downloaded: sets.count,
          total_cards: total_cards,
          unique_cards_owned: unique_owned,
          total_cards_owned: owned_cards,
          total_regular: CollectionCard.sum(:quantity).to_i,
          total_foils: CollectionCard.sum(:foil_quantity).to_i,
          sets: sets.map do |set|
            owned = set.cards.joins(:collection_card)
                       .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                       .count
            {
              code: set.code,
              name: set.name,
              cards_in_set: set.cards.count,
              cards_owned: owned,
              completion_percentage: set.cards.count > 0 ? (owned.to_f / set.cards.count * 100).round(1) : 0
            }
          end
        }
      end
    end
  end
end
