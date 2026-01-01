class AddIncludeSubsetsToCardSets < ActiveRecord::Migration[8.1]
  def change
    add_column :card_sets, :include_subsets, :boolean, default: false
  end
end
