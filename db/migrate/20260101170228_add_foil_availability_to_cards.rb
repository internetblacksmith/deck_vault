class AddFoilAvailabilityToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :foil, :boolean, default: true
    add_column :cards, :nonfoil, :boolean, default: true
  end
end
