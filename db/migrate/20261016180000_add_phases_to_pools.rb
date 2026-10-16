class AddPhasesToPools < ActiveRecord::Migration[8.2]
  def change
    add_column :pools, :phases, :json, null: false, default: [] # a linked pool's [{ "name", "size" }]
    add_column :pools, :phase, :integer, null: false, default: 0 # index of the current phase

    add_column :rolls, :phase, :string # the phase a linked pool roll was on
    add_column :rolls, :next_phase, :string # "4d Tail" when that roll ended its phase
  end
end
