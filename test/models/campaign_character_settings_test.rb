require "test_helper"

# The GM's character settings and the option rules (Campaign::CharacterSettings,
# Character::TableSettings).
class CampaignCharacterSettingsTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @pip, @gwen = identities(:pip), identities(:gwen)
  end

  def new_character(**attributes)
    @pip.characters.new(name: "Kit", path: "Rogue", brawn: 1, agility: 3, wits: 2, presence: 2, campaign: @campaign, **attributes)
  end

  test "with players' characters off, only the GM makes and seats them" do
    @campaign.update!(players_make_characters: false)
    character = new_character
    assert_not character.valid?
    assert_match "The GM makes the characters", character.errors.full_messages.to_sentence

    assert @gwen.characters.new(name: "Mote", path: "Bard", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign, up_for_grabs: true).valid?
    assert @tibbs.update(spark: 2), "a character already seated stays"
  end

  test "a starting level puts new characters there" do
    @campaign.update!(starting_level: 3)
    character = new_character(level: 1)
    character.save!
    assert_equal [ 3, 3 ], [ character.level, character.talents_to_choose ]
  end

  test "starting at level 0 needs the Level 0 rule" do
    @campaign.update!(optional_rules: [])
    assert_not @campaign.update(starting_level: 0)
    @campaign.update!(optional_rules: %w[ level_zero ], starting_level: 0)
    character = new_character(brawn: 1, agility: 2, wits: 2, presence: 2)
    character.save!
    assert_equal [ 0, true ], [ character.level, character.level_zero? ]
  end

  test "closed paths can't be taken, but a character keeps theirs" do
    @campaign.update!(allowed_paths: %w[ Fighter Bard ])
    assert_not new_character(path: "Rogue").valid?
    assert new_character(path: "Bard").valid?
    assert @tibbs.update(spark: 2), "Tibbs is a Rogue already"
    assert_not @tibbs.update(path: "Wizard")

    @campaign.update!(allowed_paths: Grimwild.paths.keys)
    assert_empty @campaign.allowed_paths, "all ticked is every path"
    assert_not @campaign.update(allowed_paths: [ "" ])
  end

  test "stat progression, legacy cores and level 0 need the GM's say-so at a table, not off one" do
    @campaign.update!(optional_rules: [])
    @tibbs.update!(level: 2)
    assert_not @tibbs.can_progress_stat?("wits")
    assert_not @tibbs.update(legacy_core: true)
    assert_not new_character(level_zero: true, brawn: 1, agility: 2, wits: 2, presence: 2).valid?

    @tibbs.update!(campaign: nil)
    assert @tibbs.can_progress_stat?("wits"), "no table, no GM to ask"
  end
end
