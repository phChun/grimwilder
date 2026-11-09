# The armor a character wears under the Armor optional rule (pg. 176):
# light or heavy, for a 1d or 2d Armor pool (Character::RulePools).
class AddArmorToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :armor, :string
  end
end
