# frozen_string_literal: true

# Consolidated initial migration for MTG Collector
# Combines all migrations into a single schema setup
class CreateInitialSchema < ActiveRecord::Migration[8.1]
  def change
    # Users table for authentication
    create_table :users do |t|
      t.string :username
      t.string :password_digest

      t.timestamps
    end

    # Card sets from Scryfall
    create_table :card_sets do |t|
      t.string :code
      t.string :name
      t.date :released_at
      t.integer :card_count
      t.string :scryfall_uri
      t.string :download_status, default: "pending"
      t.integer :images_downloaded, default: 0
      t.string :set_type
      t.string :parent_set_code
      t.boolean :include_subsets, default: false

      # Binder view settings
      t.integer :binder_rows, default: 3
      t.integer :binder_columns, default: 3
      t.string :binder_sort_field, default: "number"
      t.string :binder_sort_direction, default: "asc"

      t.timestamps
    end

    # Cards from Scryfall (uses Scryfall ID as primary key)
    create_table :cards, id: :string do |t|
      t.references :card_set, null: false, foreign_key: true
      t.string :name
      t.string :collector_number
      t.string :type_line
      t.string :mana_cost
      t.string :rarity
      t.text :oracle_text
      t.text :image_uris
      t.string :image_path
      t.text :back_image_uris
      t.string :back_image_path
      t.boolean :foil, default: true
      t.boolean :nonfoil, default: true

      t.timestamps
    end

    # User's collection tracking
    create_table :collection_cards do |t|
      t.references :card, type: :string, foreign_key: true
      t.integer :quantity
      t.integer :foil_quantity
      t.integer :page_number
      t.text :notes

      t.timestamps
    end
  end
end
