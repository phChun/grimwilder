# Picks a talent asks for (Character::TalentChoices), keyed by talent key then
# choice key: { "expertise" => { "skills" => ["stealth", "lying", "duel"] } }.
class AddTalentChoicesToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :talent_choices, :json, default: {}, null: false
  end
end
