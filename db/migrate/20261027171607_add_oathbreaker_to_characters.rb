# A Paladin who breaks their oath (P6 pg. 69): Oathsworn gives way to the
# Adventurer's Talented until redeemed, which can happen only once. And a
# character who started at level 0 (optional rule, pg. 177), who adds their
# last stat point at level 1.
class AddOathbreakerToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :oathbroken_at, :datetime
    add_column :characters, :oath_redeemed_at, :datetime
    add_column :characters, :level_zero, :boolean, default: false, null: false
  end
end
