# A character the GM has made, or taken back, for a player at the table to
# pick (Character::Claiming).
class AddUpForGrabsToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :up_for_grabs, :boolean, default: false, null: false
  end
end
