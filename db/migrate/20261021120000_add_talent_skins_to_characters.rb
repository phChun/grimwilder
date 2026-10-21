# Re-skinned talents (pg. 52): a character's own name, summary and text for a
# talent, keyed by talent key. The book's mechanics stay as they are.
class AddTalentSkinsToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :talent_skins, :json, default: {}, null: false
  end
end
