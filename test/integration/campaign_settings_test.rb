require "test_helper"

# Campaign settings' Characters and Optional rules sections.
class CampaignSettingsTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "the GM sets the character settings and the rules, each section on its own" do
    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "#settings-characters input[type=checkbox][name='campaign[allowed_paths][]'][checked]", Grimwild.paths.size, "every path ticked by default"
    assert_equal Campaign::OptionalRules::GROUPS.keys, css_select("#settings-rules fieldset legend").map(&:text)

    patch campaign_path(@campaign), params: { section: "settings-characters", campaign: { players_make_characters: "0", players_set_level: "0", starting_level: "2", allowed_paths: [ "", "Fighter", "Bard" ] } }
    assert_redirected_to edit_campaign_path(@campaign, anchor: "settings-characters")
    @campaign.reload
    assert_equal [ false, false, 2, %w[ Fighter Bard ] ], [ @campaign.players_make_characters?, @campaign.players_set_level?, @campaign.starting_level, @campaign.allowed_paths ]
    assert_equal %w[ stat_progression legacy_cores level_zero ], @campaign.optional_rules, "the rules section wasn't touched"

    patch campaign_path(@campaign), params: { section: "settings-rules", campaign: { optional_rules: [ "", "vigor_pool" ] } }
    assert_equal %w[ vigor_pool ], @campaign.reload.optional_rules
  end

  test "players don't set their own level when the GM keeps it to XP" do
    @campaign.update!(players_set_level: false)
    tibbs = characters(:tibbs)
    sign_in_as identities(:pip)
    get edit_character_path(tibbs)
    assert_select "input[name='character[level]']", 0
    patch character_path(tibbs), params: { character: { level: 5, name: tibbs.name } }
    assert_equal 1, tibbs.reload.level
  end

  test "with players' characters off, the campaign page points players to up-for-grabs ones" do
    @campaign.update!(players_make_characters: false)
    characters(:tibbs).update_columns(status: "retired")
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "a", text: "Make your character", count: 0
  end
end
