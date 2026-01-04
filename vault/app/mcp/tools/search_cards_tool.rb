# frozen_string_literal: true

module Mcp
  module Tools
    class SearchCardsTool < MCP::Tool
      tool_name "search_cards"
      description "Search for cards in your collection by name, set, rarity, or other criteria"

      input_schema(
        properties: {
          query: {
            type: "string",
            description: "Search query - card name or partial name"
          },
          set_code: {
            type: "string",
            description: "Filter by set code (optional)"
          },
          rarity: {
            type: "string",
            enum: %w[common uncommon rare mythic],
            description: "Filter by rarity (optional)"
          },
          owned_only: {
            type: "boolean",
            description: "Only show cards you own (default: false)"
          }
        },
        required: []
      )

      class << self
        def call(query: nil, set_code: nil, rarity: nil, owned_only: false, server_context:)
          cards = Card.includes(:collection_card, :card_set)

          cards = cards.where("cards.name LIKE ?", "%#{query}%") if query.present?
          cards = cards.joins(:card_set).where(card_sets: { code: set_code.downcase }) if set_code.present?
          cards = cards.where(rarity: rarity) if rarity.present?

          if owned_only
            cards = cards.joins(:collection_card)
                         .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
          end

          results = cards.limit(50).map do |card|
            {
              id: card.id,
              name: card.name,
              set: card.card_set.name,
              set_code: card.card_set.code,
              number: card.collector_number,
              rarity: card.rarity,
              quantity: card.collection_card&.quantity.to_i,
              foil_quantity: card.collection_card&.foil_quantity.to_i
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
