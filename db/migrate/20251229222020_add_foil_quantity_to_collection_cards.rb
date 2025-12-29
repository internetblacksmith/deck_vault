class AddFoilQuantityToCollectionCards < ActiveRecord::Migration[8.1]
  def change
    add_column :collection_cards, :foil_quantity, :integer
  end
end
