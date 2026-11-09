require "test_helper"

# The Adventurer and Oathbreaker on the sheet, level 0 from the form,
# and weapon styles as a table's optional rule.
class PathsTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs) # pip's Rogue at gwen's table, Bramblewood
    @campaign = campaigns(:bramblewood)
  end

  test "a Paladin breaks the oath from the core talent card, and is redeemed once" do
    @tibbs.update!(path: "Paladin", level: 2, talent_keys: %w[ aegis lucky ])
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "#talent-oathsworn form[action=?] button", character_oath_path(@tibbs), text: /Oathbreaker/

    post character_oath_path(@tibbs)
    follow_redirect!
    assert_select "#talent-talented .oath", /Oathbreaker/
    assert_select "#talent-talented form[action=?][method=post] input[name=_method][value=delete]", character_oath_path(@tibbs)

    delete character_oath_path(@tibbs)
    follow_redirect!
    assert_select "#talent-oathsworn"
    assert_select "#talent-oathsworn .oath button", text: /Oathbreaker/ # it can break again…

    post character_oath_path(@tibbs)
    follow_redirect!
    assert_select "#talent-talented .oath button", 0 # …but redemption was once
    assert_select "#talent-talented .oath", /already redeemed once/
  end

  test "an Adventurer's picker opens on every talent" do
    @tibbs.update!(path: "Adventurer", talent_keys: [])
    sign_in_as identities(:pip)
    get new_character_talent_path(@tibbs)
    assert_select "select#talent-path option[selected][value='']", "All talents"
    assert_select ".talent-group[hidden]", 0
  end

  test "starting at level 0 from the form, then the last stat point at level 1" do
    sign_in_as identities(:pip)
    get new_character_path
    assert_select "input[type=checkbox][name='character[level_zero]']"

    post characters_path, params: { character: { name: "Kit", path: "Rogue", level_zero: "1", brawn: 1, agility: 2, wits: 2, presence: 2 } }
    kit = Character.find_by!(name: "Kit")
    assert_equal 0, kit.level
    get character_path(kit)
    assert_response :success
    assert_select ".talent-card--core", 0, "no core talent at level 0"
    get new_character_talent_path(kit)
    assert_select ".page-header__lede", /no core talent until level 1/

    patch character_path(kit), params: { character: { level_zero: "0", level: 1 } }
    assert kit.reload.level_zero?, "only a new character starts at level 0"

    get character_path(kit)
    assert_select ".stat-point button", text: "+1 Wits"
    post character_stat_point_path(kit), params: { stat: "wits" }
    assert_equal 3, kit.reload.wits
  end

  test "weapon styles are asked for only at a table that uses the rule" do
    sign_in_as identities(:pip)
    get edit_character_path(@tibbs)
    assert_select "input[name='character[weapon_styles][]']", 0

    @campaign.update!(optional_rules: %w[ weapon_styles ])
    get edit_character_path(@tibbs)
    assert_select "input[name='character[weapon_styles][]']", 2
  end

  test "the GM turns optional rules on in settings" do
    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "input#rule-weapon_styles[type=checkbox]"

    patch campaign_path(@campaign), params: { campaign: { optional_rules: [ "", "weapon_styles", "nonsense" ] } }
    assert_equal %w[ weapon_styles ], @campaign.reload.optional_rules
    patch campaign_path(@campaign), params: { campaign: { optional_rules: [ "" ] } }
    assert_empty @campaign.reload.optional_rules
  end
end
