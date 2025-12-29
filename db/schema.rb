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

ActiveRecord::Schema[8.1].define(version: 2025_12_29_222020) do
  create_table "card_sets", force: :cascade do |t|
    t.integer "binder_columns", default: 3
    t.integer "binder_rows", default: 3
    t.string "binder_sort_direction", default: "asc"
    t.string "binder_sort_field", default: "number"
    t.integer "card_count"
    t.string "code"
    t.datetime "created_at", null: false
    t.string "download_status", default: "pending"
    t.integer "images_downloaded", default: 0
    t.string "name"
    t.string "parent_set_code"
    t.date "released_at"
    t.string "scryfall_uri"
    t.string "set_type"
    t.datetime "updated_at", null: false
  end

  create_table "cards", force: :cascade do |t|
    t.integer "card_set_id", null: false
    t.string "collector_number"
    t.datetime "created_at", null: false
    t.string "image_path"
    t.text "image_uris"
    t.string "mana_cost"
    t.string "name"
    t.text "oracle_text"
    t.string "rarity"
    t.string "scryfall_id"
    t.string "type_line"
    t.datetime "updated_at", null: false
    t.index ["card_set_id"], name: "index_cards_on_card_set_id"
  end

  create_table "collection_cards", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "foil_quantity"
    t.text "notes"
    t.integer "page_number"
    t.integer "quantity"
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_collection_cards_on_card_id"
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
