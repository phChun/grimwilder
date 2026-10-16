class AddAssistsToRolls < ActiveRecord::Migration[8.2]
  def change
    add_column :rolls, :assists, :json, null: false, default: [] # [{ character_id, name, die }]
  end
end
