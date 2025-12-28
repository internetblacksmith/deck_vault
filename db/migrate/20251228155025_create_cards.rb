class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :card_set, null: false, foreign_key: true
      t.string :name
      t.string :mana_cost
      t.string :type_line
      t.text :oracle_text
      t.string :rarity
      t.string :scryfall_id
      t.text :image_uris
      t.string :collector_number

      t.timestamps
    end
  end
end
