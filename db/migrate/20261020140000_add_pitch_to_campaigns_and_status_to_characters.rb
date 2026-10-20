# The campaign page's hero: a one-line pitch, the setting, what the party is
# (two concepts) and never is (one), and the group arc (pg. 26). And whether a
# character is still playing, fell, or retired.
class AddPitchToCampaignsAndStatusToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :campaigns, :pitch, :string
    add_column :campaigns, :setting, :string
    add_column :campaigns, :party_is, :json, default: [], null: false
    add_column :campaigns, :party_never, :string
    add_column :campaigns, :group_arc, :string

    add_column :characters, :status, :string, default: "active", null: false
  end
end
