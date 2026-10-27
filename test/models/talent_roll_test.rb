require "test_helper"

# Talent::Roll (config/talents.yml `rolls:`), the badges on a talent's card,
# and what a player does from the card (Character::TalentActions).
class TalentRollTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "every roll is well formed, and any use it ticks is the talent's own" do
    rolled = Talent.all.select { _1.rolls.any? }
    assert rolled.size >= 15

    rolled.each do |talent|
      talent.rolls.each do |roll|
        assert_includes Talent::Roll::KINDS, roll.kind, talent.key
        assert roll.label.present?, talent.key
        assert_includes Roll::ODDS.keys, roll.odds, talent.key if roll.story?
        assert_includes talent.uses.select(&:counter?).map(&:id), roll.use_id, talent.key if roll.use
      end
    end
    assert_equal "3d story roll", Talent.find("pact").rolls.sole.dice_label
    assert_equal "3d montage", Talent.find("scout-ahead").rolls.sole.dice_label
    assert_equal "1 thread", Talent.find("mastermind").rolls.sole.cost
  end

  test "badges say what a talent does, and a core talent's growth stands on its own" do
    assert_equal %w[ Uses ], Talent.find("inspiration").kinds
    assert_equal %w[ Spell Pool ], Talent.find("channel-divinity").kinds
    assert_equal %w[ Roll Uses Push ], Talent.find("weasel").kinds
    assert_equal %w[ Always ], Talent.find("aquatic").kinds
    pact = Talent.find("pact")
    assert_equal "At levels 3 and 6, gain +1 Eldritch Talent.", pact.growth
    assert pact.paragraphs.none? { _1.include?("GROWTH") }
  end

  test "a talent's roll is a roll call for the character, after spending what it asks" do
    @tibbs.update!(talent_keys: [ "mastermind" ], thread: 2)

    assert_difference -> { @campaign.roll_calls.count }, 1 do
      @tibbs.call_talent_roll!("mastermind", 0, by: identities(:pip))
    end
    call = @campaign.roll_calls.last
    assert call.montage?
    assert_equal "Mastermind: Flashback: the preparation", call.question
    assert_equal 1, @tibbs.reload.thread

    error = assert_raises(ArgumentError) { @tibbs.call_talent_roll!("mastermind", 0, by: identities(:pip)) }
    assert_match "waiting", error.message
    assert_equal 1, @tibbs.reload.thread, "the thread comes back when the call can't be made"
  end

  test "a story roll at the talent's odds, ticking its use; a montage's extra dice" do
    pip = identities(:pip)
    @tibbs.update!(level: 2, talent_keys: %w[ mastermind weasel ])
    @tibbs.call_talent_roll!("weasel", 0, by: pip)
    call = @campaign.roll_calls.last
    assert call.story?
    assert_equal 2, call.odds
    assert_equal 1, @tibbs.reload.uses_spent(@tibbs.use_counters.find { _1.key == "weasel" })
    call.cancel!(by: pip)

    error = assert_raises(ArgumentError) { @tibbs.call_talent_roll!("weasel", 0, by: pip) }
    assert_match "No weasel left", error.message

    call = RollCall.montage!(campaign: @campaign, by: pip, characters: [ @tibbs ], bonus: 1)
    assert_equal 3, call.base_dice(call.seats.first)
    call.roll!(@tibbs, by: pip, random: FixedDice.new([ 2, 3, 6 ]))
    assert_equal "perfect", call.reload.roll.outcome
  end

  test "no table, no roll" do
    loner = characters(:loner)
    loner.update!(talent_keys: [ "relentless" ])
    assert_raises(ActiveRecord::RecordNotFound) { loner.call_talent_roll!("pact", 0, by: identities(:stranger)) }
    loner.update!(path: "Warlock", talent_keys: [])
    error = assert_raises(ArgumentError) { loner.call_talent_roll!("pact", 0, by: identities(:stranger)) }
    assert_match "Seat Wren in a campaign", error.message
  end

  test "pushing yourself marks a stat; a marked one takes harm, then desperate, then dropped" do
    @tibbs.update!(talent_keys: [ "lurker" ])
    pip = identities(:pip)

    assert_equal "marks Agility", @tibbs.push!("agility", talent_key: "lurker", by: pip)
    assert @tibbs.reload.marked_agility?
    assert_equal "Tibbs pushes for Lurker and marks Agility.", @campaign.rolls.last.question

    assert_equal "is bloodied", @tibbs.push!("agility", talent_key: "lurker", by: pip)
    assert @tibbs.reload.bloodied?
    assert_equal "marks Brawn", @tibbs.push!("brawn", talent_key: "lurker", by: pip)
    assert_equal "is desperate", @tibbs.push!("brawn", talent_key: "lurker", by: pip), "a second bloodied"
    assert @tibbs.reload.desperate?
    assert_equal "dropped", @tibbs.mark_would_be("agility")

    assert_raises(ArgumentError) { @tibbs.push!("agility", talent_key: "expertise", by: pip) }
    assert_raises(ArgumentError) { @tibbs.push!("luck", talent_key: "lurker", by: pip) }
  end
end
