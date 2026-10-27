# Panache dice (pg. 80): d8s that raise a roll's result on a 7 or 8.
class AddBoostsToRolls < ActiveRecord::Migration[8.2]
  def change
    add_column :rolls, :boosts, :json, default: [], null: false
  end
end
