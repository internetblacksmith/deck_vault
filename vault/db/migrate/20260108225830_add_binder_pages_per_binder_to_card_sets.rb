class AddBinderPagesPerBinderToCardSets < ActiveRecord::Migration[8.1]
  def change
    add_column :card_sets, :binder_pages_per_binder, :integer
  end
end
