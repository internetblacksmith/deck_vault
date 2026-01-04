# frozen_string_literal: true

module Mcp
  module Tools
    class GetSetDetailsTool < MCP::Tool
      tool_name "get_set_details"
      description "Get details about a specific set including all cards and ownership status"

      input_schema(
        properties: {
          set_code: {
            type: "string",
            description: "The set code (e.g., 'tla' for Avatar: The Last Airbender)"
          }
        },
        required: [ "set_code" ]
      )

      class << self
        def call(set_code:, server_context:)
          set = CardSet.find_by(code: set_code.downcase)

          unless set
            return MCP::Tool::Response.new([ {
              type: "text",
              text: JSON.pretty_generate({ error: "Set '#{set_code}' not found. Use list_sets to see available sets." })
            } ])
          end

          cards = set.cards.includes(:collection_card).order(:collector_number).map do |card|
            {
              id: card.id,
              name: card.name,
              number: card.collector_number,
              rarity: card.rarity,
              quantity: card.collection_card&.quantity.to_i,
              foil_quantity: card.collection_card&.foil_quantity.to_i
            }
          end

          result = {
            set_code: set.code,
            set_name: set.name,
            total_cards: cards.count,
            cards: cards
          }

          MCP::Tool::Response.new([ {
            type: "text",
            text: JSON.pretty_generate(result)
          } ])
        end
      end
    end
  end
end
