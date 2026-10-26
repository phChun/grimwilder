# The path's legacy core talent in place of its own (pg. 178).
class AddLegacyCoreToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :legacy_core, :boolean, default: false, null: false
  end
end
