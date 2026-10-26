# Talents that change a roll after it's made (Roll::FollowUps).
class AddFollowUpsToRolls < ActiveRecord::Migration[8.2]
  def change
    add_column :rolls, :follow_ups, :json, default: [], null: false
  end
end
