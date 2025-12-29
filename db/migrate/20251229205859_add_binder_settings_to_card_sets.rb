class AddBinderSettingsToCardSets < ActiveRecord::Migration[8.1]
  def change
    add_column :card_sets, :binder_rows, :integer, default: 3
    add_column :card_sets, :binder_columns, :integer, default: 3
    add_column :card_sets, :binder_sort_field, :string, default: "number"
    add_column :card_sets, :binder_sort_direction, :string, default: "asc"
  end
end
