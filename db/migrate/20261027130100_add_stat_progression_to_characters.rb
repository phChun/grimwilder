# The optional stat progression rule (pg. 175): a talent given up for +1 to this stat.
class AddStatProgressionToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :stat_progression, :string
  end
end
