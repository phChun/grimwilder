# A warlock's Eldritch Talents (Pact, pg. 82), kept apart from the one
# chosen talent per level (Character::EldritchTalents).
class AddEldritchTalentKeysToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :eldritch_talent_keys, :json, default: [], null: false
  end
end
