# Expanded downtime (optional rule, pg. 142): a character's plan-ahead thread
# and what it's for, kept until the next downtime, and goal pools they pursue.
class AddExpandedDowntime < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :prep_note, :string
    add_column :characters, :prep_thread, :integer, null: false, default: 0
    add_column :pools, :goal, :boolean, null: false, default: false
  end
end
