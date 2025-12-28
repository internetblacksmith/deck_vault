class AddImagePathToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :image_path, :string
  end
end
