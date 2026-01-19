# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_19_204454) do
  create_table "card_sets", force: :cascade do |t|
    t.integer "binder_columns", default: 3
    t.integer "binder_pages_per_binder"
    t.integer "binder_rows", default: 3
    t.string "binder_sort_direction", default: "asc"
    t.string "binder_sort_field", default: "number"
    t.integer "card_count"
    t.string "code"
    t.datetime "created_at", null: false
    t.string "download_status", default: "pending"
    t.integer "images_downloaded", default: 0
    t.boolean "include_subsets", default: false
    t.string "name"
    t.string "parent_set_code"
    t.date "released_at"
    t.string "scryfall_uri"
    t.string "set_type"
    t.datetime "updated_at", null: false
  end

  create_table "cards", id: :string, force: :cascade do |t|
    t.string "back_image_path"
    t.text "back_image_uris"
    t.integer "card_set_id", null: false
    t.string "collector_number"
    t.datetime "created_at", null: false
    t.boolean "foil", default: true
    t.string "image_path"
    t.text "image_uris"
    t.string "mana_cost"
    t.string "name"
    t.boolean "nonfoil", default: true
    t.text "oracle_text"
    t.string "rarity"
    t.string "type_line"
    t.datetime "updated_at", null: false
    t.index ["card_set_id"], name: "index_cards_on_card_set_id"
  end

  create_table "collection_cards", force: :cascade do |t|
    t.string "card_id"
    t.datetime "created_at", null: false
    t.integer "foil_quantity"
    t.datetime "needs_placement_at"
    t.text "notes"
    t.integer "page_number"
    t.integer "quantity"
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_collection_cards_on_card_id"
    t.index ["needs_placement_at"], name: "index_collection_cards_on_needs_placement_at"
    t.index ["quantity", "foil_quantity"], name: "index_collection_cards_on_quantities"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "encrypted", default: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.string "username"
  end

  add_foreign_key "cards", "card_sets"
  add_foreign_key "collection_cards", "cards"
end
