class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false
      t.text :value
      t.boolean :encrypted, default: false

      t.timestamps
    end
    add_index :settings, :key, unique: true
  end
end
