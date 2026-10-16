class CreateRolls < ActiveRecord::Migration[8.2]
  def change
    create_table :rolls do |t|
      t.references :campaign, foreign_key: true
      t.references :identity, null: false, foreign_key: true
      t.references :character, foreign_key: { on_delete: :nullify }
      t.references :pool, foreign_key: { on_delete: :nullify }

      t.string :kind, null: false
      t.string :name, null: false
      t.string :stat
      t.json :dice, null: false, default: []
      t.json :thorns, null: false, default: []

      # Action and defense rolls
      t.integer :stat_dice, null: false, default: 0
      t.integer :help_dice, null: false, default: 0
      t.integer :spark_spent, null: false, default: 0
      t.json :damage_reasons, null: false, default: []
      t.string :outcome
      t.boolean :critical, null: false, default: false
      t.boolean :spark_gained, null: false, default: false

      # Pool rolls
      t.string :pool_action
      t.integer :dropped
      t.integer :remaining
      t.boolean :gm_only, null: false, default: false

      t.timestamps
    end

    add_index :rolls, %i[ campaign_id created_at ]
  end
end
