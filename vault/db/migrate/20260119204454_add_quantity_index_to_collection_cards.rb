# frozen_string_literal: true

class AddQuantityIndexToCollectionCards < ActiveRecord::Migration[8.1]
  def change
    # Add composite index for common query pattern:
    # WHERE quantity > 0 OR foil_quantity > 0
    add_index :collection_cards, [ :quantity, :foil_quantity ], name: "index_collection_cards_on_quantities"
  end
end
