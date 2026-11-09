# Vex (pg. 30): a flash of emotion and the response it prompts (fight,
# flight, freeze or freakout), and what it's aimed at, until it passes.
class AddVexToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :vex, :string
    add_column :characters, :vex_subject, :string
  end
end
