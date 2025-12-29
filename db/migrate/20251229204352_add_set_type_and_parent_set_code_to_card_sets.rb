class AddSetTypeAndParentSetCodeToCardSets < ActiveRecord::Migration[8.1]
  def change
    add_column :card_sets, :set_type, :string
    add_column :card_sets, :parent_set_code, :string
  end
end
