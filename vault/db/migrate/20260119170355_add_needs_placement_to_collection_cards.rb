class AddNeedsPlacementToCollectionCards < ActiveRecord::Migration[8.1]
  def change
    add_column :collection_cards, :needs_placement_at, :datetime
    add_index :collection_cards, :needs_placement_at
  end
end
