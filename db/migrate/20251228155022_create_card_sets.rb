class CreateCardSets < ActiveRecord::Migration[8.1]
  def change
    create_table :card_sets do |t|
      t.string :code
      t.string :name
      t.date :released_at
      t.integer :card_count
      t.string :scryfall_uri

      t.timestamps
    end
  end
end
