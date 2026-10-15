class CreateCharacters < ActiveRecord::Migration[8.2]
  def change
    create_table :characters do |t|
      t.references :identity, null: false, foreign_key: true
      t.references :campaign, foreign_key: true

      t.string :name, null: false
      t.string :path, null: false
      t.integer :level, null: false, default: 1
      t.integer :xp, null: false, default: 0

      t.integer :brawn, null: false, default: 1
      t.integer :agility, null: false, default: 1
      t.integer :wits, null: false, default: 1
      t.integer :presence, null: false, default: 1

      t.integer :spark, null: false, default: 0
      t.integer :thread, null: false, default: 2

      # Damage (pg. 27–29)
      t.boolean :marked_brawn, null: false, default: false
      t.boolean :marked_agility, null: false, default: false
      t.boolean :marked_wits, null: false, default: false
      t.boolean :marked_presence, null: false, default: false
      t.boolean :bloodied, null: false, default: false
      t.boolean :rattled, null: false, default: false
      t.boolean :desperate, null: false, default: false
      t.json :conditions, null: false, default: []

      # Details (pg. 20–26)
      t.json :backgrounds, null: false, default: []
      t.json :traits, null: false, default: []
      t.string :not_trait
      t.json :desires, null: false, default: []
      t.string :not_desire
      t.json :features, null: false, default: []
      t.string :weapons
      t.json :weapon_styles, null: false, default: []
      t.json :arcs, null: false, default: []
      t.json :bonds, null: false, default: []
      t.text :talents
      t.text :notes

      t.timestamps
    end
  end
end
