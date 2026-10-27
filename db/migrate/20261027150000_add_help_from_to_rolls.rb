# Outside help as its own named die: "1d from the innkeeper".
class AddHelpFromToRolls < ActiveRecord::Migration[8.2]
  def change
    add_column :rolls, :help_from, :string
  end
end
