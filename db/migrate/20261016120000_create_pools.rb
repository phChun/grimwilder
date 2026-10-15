class CreatePools < ActiveRecord::Migration[8.2]
  def change
    create_table :pools do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false, default: "task"
      t.integer :starting_size, null: false
      t.integer :size, null: false
      t.boolean :hidden, null: false, default: false

      # The most recent roll, shown on the pool's card
      t.json :last_dice, null: false, default: []
      t.integer :last_dropped
      t.string :last_action
      t.references :last_rolled_by, foreign_key: { to_table: :identities }
      t.datetime :last_rolled_at

      t.timestamps
    end
  end
end
