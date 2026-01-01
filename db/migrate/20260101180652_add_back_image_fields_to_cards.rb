class AddBackImageFieldsToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :back_image_uris, :text
    add_column :cards, :back_image_path, :string
  end
end
