# frozen_string_literal: true

module Mcp
  module Tools
    class UpdateCardQuantityTool < MCP::Tool
      tool_name "update_card_quantity"
      description "Update the quantity of a card in your collection"

      input_schema(
        properties: {
          card_id: {
            type: "string",
            description: "The Scryfall ID of the card"
          },
          quantity: {
            type: "integer",
            description: "New quantity of regular (non-foil) copies"
          },
          foil_quantity: {
            type: "integer",
            description: "New quantity of foil copies"
          }
        },
        required: [ "card_id" ]
      )

      class << self
        def call(card_id:, quantity: nil, foil_quantity: nil, server_context:)
          card = Card.includes(:collection_card, :card_set).find_by(id: card_id)

          unless card
            return MCP::Tool::Response.new([ {
              type: "text",
              text: JSON.pretty_generate({ error: "Card not found: #{card_id}" })
            } ])
          end

          collection = card.collection_card || CollectionCard.new(card: card)
          collection.quantity = quantity if quantity.present?
          collection.foil_quantity = foil_quantity if foil_quantity.present?
          collection.save!

          result = {
            success: true,
            card: card.name,
            set: card.card_set.name,
            quantity: collection.quantity.to_i,
            foil_quantity: collection.foil_quantity.to_i
          }

          MCP::Tool::Response.new([ {
            type: "text",
            text: JSON.pretty_generate(result)
          } ])
        rescue StandardError => e
          MCP::Tool::Response.new([ {
            type: "text",
            text: JSON.pretty_generate({ error: e.message })
          } ])
        end
      end
    end
  end
end
