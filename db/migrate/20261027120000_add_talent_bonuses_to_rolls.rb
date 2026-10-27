# Talent bonuses on a roll (Talent::Bonus): which talents added dice, by name.
class AddTalentBonusesToRolls < ActiveRecord::Migration[8.2]
  def change
    add_column :rolls, :talent_bonuses, :json, default: [], null: false
  end
end
