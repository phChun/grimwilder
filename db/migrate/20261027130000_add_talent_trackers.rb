# What talents keep track of (talent-ui brief §E): pools that refill at 0d or
# are made when used, and per-talent state (omens, herbs, frenzy, quarries).
class AddTalentTrackers < ActiveRecord::Migration[8.2]
  def change
    add_column :pools, :refills_used, :integer, default: 0, null: false
    add_column :pools, :made_by_talent, :boolean, default: false, null: false
    add_column :rolls, :refilled, :boolean, default: false, null: false
    add_column :characters, :talent_state, :json, default: {}, null: false

    # A talent can make several of a pool (three animated objects).
    remove_index :pools, %i[ character_id use_key ], unique: true
    add_index :pools, %i[ character_id use_key ], unique: true, where: "made_by_talent = 0"
  end
end
