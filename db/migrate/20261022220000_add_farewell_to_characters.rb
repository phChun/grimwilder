# When a character fell or retired, and the player's line on how their story
# ended (Character::Farewell).
class AddFarewellToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :status_changed_at, :datetime
    add_column :characters, :farewell, :string
  end
end
