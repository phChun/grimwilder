# The GM's character settings for a table (Campaign::CharacterSettings): who
# makes characters, the level they start at, whether players set their own
# level, and which paths are open. Stat progression, legacy cores and level 0
# become optional rules the GM turns on; existing tables keep them on, so
# nothing changes for anyone already playing.
class AddCharacterSettingsToCampaigns < ActiveRecord::Migration[8.2]
  OPTIONS = %w[ stat_progression legacy_cores level_zero ].freeze

  def up
    add_column :campaigns, :players_make_characters, :boolean, default: true, null: false
    add_column :campaigns, :players_set_level, :boolean, default: true, null: false
    add_column :campaigns, :starting_level, :integer
    add_column :campaigns, :allowed_paths, :json, default: [], null: false

    select_rows("SELECT id, optional_rules FROM campaigns").each do |id, rules|
      rules = (JSON.parse(rules.presence || "[]") | OPTIONS).to_json
      execute "UPDATE campaigns SET optional_rules = #{connection.quote(rules)} WHERE id = #{id.to_i}"
    end
  end

  def down
    remove_column :campaigns, :players_make_characters
    remove_column :campaigns, :players_set_level
    remove_column :campaigns, :starting_level
    remove_column :campaigns, :allowed_paths
  end
end
