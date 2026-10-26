require "test_helper"

# Talents that change a roll after it's made (Talent::FollowUp, Roll::FollowUps).
class RollFollowUpTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram) # Tibbs is pip's Rogue; Bram is gwen's Fighter
    @pip, @gwen = identities(:pip), identities(:gwen)
  end

  test "every follow-up is well formed: its use, pool and bonus are the talent's own" do
    followed = Talent.all.select { _1.follow_ups.any? }
    assert followed.size >= 9

    followed.each do |talent|
      talent.follow_ups.each do |follow_up|
        assert_includes Talent::FollowUp::KINDS, follow_up.kind, follow_up.id
        assert_includes Talent::FollowUp::WHO, follow_up.who, follow_up.id
        assert (follow_up.rolls - Talent::FollowUp::ROLLS).empty?, follow_up.id
        assert (follow_up.results - Grimwild::Dice::RESULTS).empty?, follow_up.id
        assert_includes Talent::FollowUp::SPARK, follow_up.spark, follow_up.id if follow_up.spark
        assert_includes talent.uses.select(&:counter?).map(&:id), follow_up.use_id, follow_up.id if follow_up.use
        assert_includes talent.uses.select(&:pool?).map(&:id), follow_up.pool_id, follow_up.id if follow_up.pool
        assert_includes talent.bonuses.map(&:id), follow_up.after, follow_up.id if follow_up.after
      end
    end
  end

  test "Competence: bonus dice after a chosen skill, rolled from its pool" do
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel ])
    @tibbs.refresh_talent_pools!(per: :session)
    plain = @tibbs.roll!("wits", by: @pip, random: FixedDice.new([ 2, 3 ]))
    assert_empty plain.follow_ups_for([ @tibbs ]), "only after a roll that took the skill"

    roll = @tibbs.roll!("wits", by: @pip, bonuses: [ "expertise/skill" ], random: FixedDice.new([ 2, 3, 1 ]))
    assert_equal [ "expertise/competence" ], roll.follow_ups_for([ @tibbs ]).map { _3.id }

    roll.follow_up!(@tibbs, "expertise/competence", by: @pip, random: FixedDice.new([ 6, 1, 5, 2 ]))
    roll.reload
    assert_equal [ [ 2, 3, 1, 6, 1, 5, 2 ], "perfect" ], [ roll.dice, roll.outcome ]
    assert_equal 2, @tibbs.talent_pools.sole.size, "the 1–3s drop from the pool"
    assert_match "then Gibbletibble \"Tibbs\"'s Expertise +4d (6, 1, 5, 2)", ApplicationController.helpers.roll_setup(roll)
    assert_empty roll.follow_ups_for([ @tibbs ]), "once per roll"
  end

  test "Blessed re-rolls without thorns, once a session, and a perfect takes spark" do
    @tibbs.update!(talent_keys: [ "blessed" ], spark: 0)
    roll = @tibbs.roll!("agility", by: @pip, thorns: 1, random: FixedDice.new([ 2, 3, 4, 8 ]))
    assert_equal "grim", roll.outcome

    roll.follow_up!(@tibbs, "blessed/reroll", by: @pip, random: FixedDice.new([ 6, 1, 2 ]))
    roll.reload
    assert_equal [ [ 6, 1, 2 ], [], "perfect" ], [ roll.dice, roll.thorns, roll.outcome ]
    assert_equal [ 2, 3, 4 ], roll.follow_ups.sole["was"]
    assert_equal 1, @tibbs.reload.spark
    assert_equal 1, @tibbs.uses_spent(@tibbs.use_counters.find { _1.key == "reroll" })

    next_roll = @tibbs.roll!("agility", by: @pip, random: FixedDice.new([ 1, 1, 1 ]))
    assert_empty next_roll.follow_ups_for([ @tibbs ]), "the re-roll is spent for the session"
  end

  test "an ally's Inspiration raises a die; only the latest, fresh roll can change" do
    @bram.update!(path: "Bard", talent_keys: [])
    roll = @tibbs.roll!("agility", by: @pip, random: FixedDice.new([ 3, 2, 1 ]))
    assert_equal [ "inspiration/inspiration" ], roll.follow_ups_for([ @bram ]).map { _3.id }
    assert_empty roll.follow_ups_for([ @tibbs ]), "Inspiration is for an ally's die"

    error = assert_raises(ArgumentError) { roll.follow_up!(@bram, "inspiration/inspiration", by: @gwen, die: 6) }
    assert_match "Pick a die below 6", error.message
    roll.follow_up!(@bram, "inspiration/inspiration", by: @gwen, die: 3)
    roll.follow_up!(@bram, "inspiration/inspiration", by: @gwen, die: 4)
    roll.reload
    assert_equal [ [ 5, 2, 1 ], "messy" ], [ roll.dice, roll.outcome ]
    assert_equal 2, @bram.reload.uses_spent(@bram.use_counters.find { _1.key == "inspiration" })
    assert_match "Bram's Inspiration raised a 3 to 4; Bram's Inspiration raised a 4 to 5", ApplicationController.helpers.roll_setup(roll)

    travel Roll::FollowUps::WINDOW + 1.minute do
      refute roll.follow_up_open?
    end
    @tibbs.roll!("wits", by: @pip, random: FixedDice.new([ 1, 1 ]))
    refute roll.reload.follow_up_open?, "a newer roll by the same character closes it"
  end

  test "Got Your Back: a late assist after an ally's grim; on a perfect both take spark" do
    @tibbs.update!(spark: 0)
    @bram.update!(spark: 0, talent_keys: [ "got-your-back" ])
    roll = @tibbs.roll!("brawn", by: @pip, random: FixedDice.new([ 2 ]))
    assert_includes roll.follow_ups_for([ @bram ]).map { _3.id }, "got-your-back/assist"

    roll.follow_up!(@bram, "got-your-back/assist", by: @gwen, random: FixedDice.new([ 6 ]))
    roll.reload
    assert_equal [ "Bram", 6 ], roll.assists.sole.values_at("name", "die")
    assert_equal "perfect", roll.outcome
    assert_equal [ 1, 1 ], [ @tibbs.reload.spark, @bram.reload.spark ]
  end

  test "Luck: a bonus die after any roll, and spark when it comes up grim; a lifted disaster keeps its spark" do
    @tibbs.update!(path: "Swashbuckler", talent_keys: [ "lucky" ], spark: 0)
    @tibbs.refresh_talent_pools!(per: :session)
    roll = @tibbs.roll!("agility", by: @pip, thorns: 1, random: FixedDice.new([ 1, 2, 3, 7 ]))
    assert_equal [ "disaster", 1 ], [ roll.outcome, @tibbs.reload.spark ]

    roll.follow_up!(@tibbs, "lucky/luck", by: @pip, random: FixedDice.new([ 2 ]))
    roll.reload
    assert_equal "disaster", roll.outcome, "a 2 doesn't help"
    assert_equal 2, @tibbs.reload.spark, "but a grim Luck die takes spark"
    assert_equal 0, @tibbs.talent_pools.sole.size

    second = @tibbs.roll!("wits", by: @pip, random: FixedDice.new([ 1, 1 ]))
    assert_empty second.follow_ups_for([ @tibbs ]), "Luck is at 0d"
  end

  test "strangers' characters and done campaigns can't follow up" do
    roll = @tibbs.roll!("agility", by: @pip, random: FixedDice.new([ 3, 2, 1 ]))
    loner = characters(:loner)
    loner.update!(path: "Bard")
    assert_empty roll.follow_ups_for([ loner ])

    @campaign.update!(done_at: Time.current)
    refute roll.reload.follow_up_open?
  end
end
