class AddTalentKeysToCharacters < ActiveRecord::Migration[8.2]
  def change
    # Keys into config/talents.yml (Talent.find). The core talent comes from the path.
    add_column :characters, :talent_keys, :json, null: false, default: []
  end
end
