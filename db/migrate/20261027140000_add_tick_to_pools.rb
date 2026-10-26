# Tick pools (optional rule, pg. 177): drop exactly 1d each time, never rolled.
class AddTickToPools < ActiveRecord::Migration[8.2]
  def change
    add_column :pools, :tick, :boolean, default: false, null: false
  end
end
