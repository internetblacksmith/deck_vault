# frozen_string_literal: true

module Mcp
  module Tools
    class GetCollectionStatsTool < MCP::Tool
      tool_name "get_collection_stats"
      description "Get statistics about your MTG card collection including total cards, sets, and owned cards"

      input_schema(
        properties: {},
        required: []
      )

      class << self
        def call(server_context:)
          sets = CardSet.where(download_status: :completed)
          total_cards = sets.sum { |s| s.cards.count }
          owned_regular = CollectionCard.sum(:quantity).to_i
          owned_foil = CollectionCard.sum(:foil_quantity).to_i

          stats = {
            sets_downloaded: sets.count,
            total_cards_in_sets: total_cards,
            unique_cards_owned: CollectionCard.where("quantity > 0 OR foil_quantity > 0").count,
            total_regular_owned: owned_regular,
            total_foils_owned: owned_foil,
            total_cards_owned: owned_regular + owned_foil
          }

          MCP::Tool::Response.new([ {
            type: "text",
            text: JSON.pretty_generate(stats)
          } ])
        end
      end
    end
  end
end
