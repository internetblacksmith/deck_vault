# frozen_string_literal: true

module Mcp
  module Tools
    class ListSetsTool < MCP::Tool
      tool_name "list_sets"
      description "List all downloaded MTG sets in your collection"

      input_schema(
        properties: {},
        required: []
      )

      class << self
        def call(server_context:)
          sets = CardSet.where(download_status: :completed).order(:name).map do |set|
            owned = set.cards.joins(:collection_card)
                       .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                       .count
            {
              code: set.code,
              name: set.name,
              cards_in_set: set.cards.count,
              cards_owned: owned,
              completion: "#{(owned.to_f / set.cards.count * 100).round(1)}%"
            }
          end

          MCP::Tool::Response.new([ {
            type: "text",
            text: JSON.pretty_generate(sets)
          } ])
        end
      end
    end
  end
end
