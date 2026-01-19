# frozen_string_literal: true

module Api
  module V1
    class StatsController < BaseController
      def index
        sets = CardSet.where(download_status: :completed)

        # Calculate totals efficiently with single queries
        total_cards = Card.joins(:card_set).where(card_sets: { download_status: :completed }).count
        collection_totals = CollectionCard.where("quantity > 0 OR foil_quantity > 0")
                                          .pluck(Arel.sql("COALESCE(SUM(quantity), 0), COALESCE(SUM(foil_quantity), 0), COUNT(*)"))
                                          .first || [ 0, 0, 0 ]
        total_regular, total_foils, unique_owned = collection_totals

        # Pre-calculate card counts and owned counts per set in single queries
        card_counts_by_set = Card.where(card_set_id: sets.pluck(:id))
                                 .group(:card_set_id)
                                 .count

        owned_counts_by_set = Card.joins(:collection_card)
                                  .where(card_set_id: sets.pluck(:id))
                                  .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                                  .group(:card_set_id)
                                  .count

        render json: {
          sets_downloaded: sets.count,
          total_cards: total_cards,
          unique_cards_owned: unique_owned,
          total_cards_owned: total_regular + total_foils,
          total_regular: total_regular,
          total_foils: total_foils,
          sets: sets.map do |set|
            cards_in_set = card_counts_by_set[set.id] || 0
            cards_owned = owned_counts_by_set[set.id] || 0
            {
              code: set.code,
              name: set.name,
              cards_in_set: cards_in_set,
              cards_owned: cards_owned,
              completion_percentage: cards_in_set > 0 ? (cards_owned.to_f / cards_in_set * 100).round(1) : 0
            }
          end
        }
      end
    end
  end
end
