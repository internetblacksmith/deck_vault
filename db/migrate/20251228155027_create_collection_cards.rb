class CreateCollectionCards < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_cards do |t|
      t.references :card, null: false, foreign_key: true
      t.integer :quantity
      t.integer :page_number
      t.text :notes

      t.timestamps
    end
  end
end
