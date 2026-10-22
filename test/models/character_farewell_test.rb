require "test_helper"

# A fallen or retired character (Character::Farewell) is out of the party: no
# rolls of any kind, no assists, rests or attendance, and every way their
# status changes says so in the log.
class CharacterFarewellTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @bram = characters(:bram)
    @pip = identities(:pip)
    @gwen = identities(:gwen)
  end

  test "a gone character takes no part in group rolls, assists, rests or the party" do
    @bram.end_story!("retired", by: @gwen)

    assert_raises(ArgumentError) { RollCall.montage!(campaign: @campaign, by: @gwen, characters: [ @tibbs, @bram ]) }
    assert_raises(ArgumentError) { @tibbs.roll!("wits", by: @pip, assists: [ @bram ]) }
    assert_not_includes @campaign.resting_characters, @bram
    assert_not_includes @tibbs.bond_party, @bram
  end

  test "a gone character can't push, roll a condition or roll a talent pool" do
    ash = @gwen.characters.create!(name: "Ash", path: "Fighter", brawn: 3, agility: 2, wits: 2, presence: 1,
      campaign: @campaign, talent_keys: [ "bulwark" ], conditions: [ "4d poisoned" ])
    ash.refresh_talent_pools!(per: :session)
    pool = ash.talent_pools.sole
    ash.end_story!("fallen", by: @gwen)

    assert_raises(ArgumentError) { ash.roll_condition!(0, by: @gwen) }
    assert_not pool.reload.rollable?
    assert_raises(ArgumentError) { pool.roll!(by: @gwen) }

    @tibbs.update!(level: 2, talent_keys: %w[ according-to-plan lurker ])
    @tibbs.end_story!("fallen", by: @pip)
    assert_raises(ArgumentError, match: /fallen/) { @tibbs.push!("wits", talent_key: "lurker", by: @pip) }
  end

  test "a gone character can't be put up for grabs, and status stays put while up for grabs" do
    @tibbs.end_story!("fallen", by: @pip)
    assert_not @tibbs.releasable_by?(@pip)

    @bram.update!(up_for_grabs: true)
    assert_not @bram.update(status: "fallen")
    assert @bram.reload.active?
  end

  test "changing status on the edit form logs it like the sheet's buttons" do
    @tibbs.changed_by = @pip
    assert_difference -> { @campaign.rolls.where(kind: "note").count }, 2 do
      @tibbs.update!(status: "retired", farewell: "Opened a bakery.")
      @tibbs.update!(status: "active")
    end
    assert_equal "Gibbletibble \"Tibbs\" returns to play.", @campaign.rolls.last.question
  end
end
