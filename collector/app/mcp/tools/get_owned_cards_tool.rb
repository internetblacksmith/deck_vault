# frozen_string_literal: true

module Mcp
  module Tools
    class GetOwnedCardsTool < MCP::Tool
      tool_name "get_owned_cards"
      description "Get all cards you own in your collection with quantities"

      input_schema(
        properties: {
          set_code: {
            type: "string",
            description: "Filter by set code (optional)"
          }
        },
        required: []
      )

      class << self
        def call(set_code: nil, server_context:)
          cards = Card.includes(:collection_card, :card_set)
                      .joins(:collection_card)
                      .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")

          cards = cards.joins(:card_set).where(card_sets: { code: set_code.downcase }) if set_code.present?

          results = cards.limit(100).map do |card|
            {
              id: card.id,
              name: card.name,
              set: card.card_set.name,
              set_code: card.card_set.code,
              quantity: card.collection_card.quantity.to_i,
              foil_quantity: card.collection_card.foil_quantity.to_i
            }
          end

          MCP::Tool::Response.new([ {
            type: "text",
            text: JSON.pretty_generate(results)
          } ])
        end
      end
    end
  end
end
