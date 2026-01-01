class UseScryfalIdAsPrimaryKeyForCards < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Remove foreign key constraint from collection_cards
    remove_foreign_key :collection_cards, :cards

    # Step 2: Add new string column for scryfall_id reference in collection_cards
    add_column :collection_cards, :card_scryfall_id, :string

    # Step 3: Migrate existing data - map old card_id to scryfall_id
    execute <<-SQL
      UPDATE collection_cards
      SET card_scryfall_id = (
        SELECT scryfall_id FROM cards WHERE cards.id = collection_cards.card_id
      )
    SQL

    # Step 4: Remove old card_id column and rename new one
    remove_index :collection_cards, :card_id
    remove_column :collection_cards, :card_id
    rename_column :collection_cards, :card_scryfall_id, :card_id

    # Step 5: Recreate cards table with scryfall_id as primary key
    # First, save all card data
    create_table :cards_new, id: false do |t|
      t.string :id, primary_key: true
      t.integer :card_set_id, null: false
      t.string :collector_number
      t.datetime :created_at, null: false
      t.string :image_path
      t.text :image_uris
      t.string :mana_cost
      t.string :name
      t.text :oracle_text
      t.string :rarity
      t.string :type_line
      t.datetime :updated_at, null: false
    end

    # Copy data from old cards table
    execute <<-SQL
      INSERT INTO cards_new (id, card_set_id, collector_number, created_at, image_path, image_uris, mana_cost, name, oracle_text, rarity, type_line, updated_at)
      SELECT scryfall_id, card_set_id, collector_number, created_at, image_path, image_uris, mana_cost, name, oracle_text, rarity, type_line, updated_at
      FROM cards
    SQL

    # Drop old table and rename new one
    drop_table :cards
    rename_table :cards_new, :cards

    # Step 6: Add indexes and foreign keys
    add_index :cards, :card_set_id
    add_foreign_key :cards, :card_sets
    add_index :collection_cards, :card_id
    add_foreign_key :collection_cards, :cards
  end

  def down
    # This is a complex migration - reversing would require keeping old IDs
    raise ActiveRecord::IrreversibleMigration
  end
end
