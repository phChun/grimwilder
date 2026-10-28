require "test_helper"

class RollTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "a story roll with no character: the odds set the dice" do
    roll = Roll.story!(campaign: @campaign, by: identities(:gwen), question: "  Any guards?  ", odds: 3, thorns: 1, random: FixedDice.new([ 2, 5, 3, 8 ]))

    assert roll.story?
    assert_equal [ [ 2, 5, 3 ], [ 8 ] ], [ roll.dice, roll.thorns ]
    assert_equal "grim", roll.outcome, "a messy, cut once"
    assert_equal [ "Gwen", "Any guards?", "good odds" ], [ roll.name, roll.question, roll.odds ]
  end

  test "a story roll for a character spends spark, and a disaster gives it" do
    roll = Roll.story!(campaign: @campaign, by: identities(:pip), character: @tibbs, odds: 1, thorns: 1, spend_spark: 1, random: FixedDice.new([ 1, 2, 7 ]))

    assert_equal 2, roll.dice.size
    assert_equal "disaster", roll.outcome
    assert roll.spark_gained?
    assert_equal 1, @tibbs.reload.spark, "spent 1, then took 1"
    assert_equal @tibbs.name, roll.name
  end

  test "a story roll for no one in particular can be the GM's alone" do
    roll = Roll.story!(campaign: @campaign, by: identities(:gwen), question: "Is the spy lying?", gm_only: true)

    assert roll.gm_only?
    assert_includes @campaign.rolls.visible_to(memberships(:gwen_gm)), roll
    assert_not_includes @campaign.rolls.visible_to(memberships(:pip_player)), roll
  end

  test "story rolls stay within the rules" do
    assert_raises(ArgumentError) { Roll.story!(campaign: @campaign, by: identities(:gwen), character: @tibbs, gm_only: true) }
    assert_raises(ArgumentError) { Roll.story!(campaign: @campaign, by: identities(:gwen), odds: 4) }
    assert_raises(ArgumentError) { Roll.story!(campaign: @campaign, by: identities(:gwen), spend_spark: 1) }
    assert_raises(ArgumentError) { Roll.story!(campaign: @campaign, by: identities(:pip), character: @tibbs, spend_spark: 2) }
  end

  test "the highest die wins a quarrel, and everyone in it takes spark" do
    roll = Roll.quarrel!(campaign: @campaign, by: identities(:pip), stakes: "Who keeps the map?",
      sides: [ { character: @tibbs, helpers: [] }, { character: @bram, helpers: [] } ], random: FixedDice.new([ 1, 5, 4, 3 ]))

    assert roll.quarrel?
    assert_equal [ "Gibbletibble \"Tibbs\" vs Bram", @tibbs.name ], [ roll.name, roll.winner ]
    assert_equal [ [ 1, 5 ], [ 4, 3 ] ], roll.sides.pluck("dice")
    assert_equal 2, @tibbs.reload.spark
    assert_equal [ true, false ], roll.sides.pluck("spark_gained"), "Bram already holds 2"
  end

  test "an assist rolls its own die, and spark adds dice" do
    @campaign.memberships.create!(identity: identities(:stranger))
    loner = characters(:loner)
    loner.update!(campaign: @campaign)

    roll = Roll.quarrel!(campaign: @campaign, by: identities(:pip),
      sides: [ { character: @tibbs, spend_spark: 1, helpers: [ loner ] }, { character: @bram, helpers: [] } ],
      random: FixedDice.new([ 1, 2, 3, 6, 5, 5 ]))

    tibbs_side = roll.sides.first
    assert_equal [ 1, 2, 3 ], tibbs_side["dice"]
    assert_equal [ [ "Wren", 6 ] ], tibbs_side["helpers"].map { _1.values_at("name", "die") }
    assert_equal @tibbs.name, roll.winner, "the assist's 6 beats Bram's 5"
    assert_equal 1, @tibbs.reload.spark, "spent 1, then took 1"
    assert_equal 1, loner.reload.spark
  end

  test "a tie has no winner" do
    roll = Roll.quarrel!(campaign: @campaign, by: identities(:pip),
      sides: [ { character: @tibbs, helpers: [] }, { character: @bram, helpers: [] } ], random: FixedDice.new([ 5, 2, 1, 5 ]))

    assert roll.tie?
    assert_nil roll.winner
  end

  test "quarrels stay within the rules" do
    one_side = [ { character: @tibbs, helpers: [] } ]
    twice = [ { character: @tibbs, helpers: [] }, { character: @bram, helpers: [ @tibbs ] } ]
    unseated = [ { character: @tibbs, helpers: [] }, { character: characters(:loner), helpers: [] } ]
    overspent = [ { character: @tibbs, spend_spark: 2, helpers: [] }, { character: @bram, helpers: [] } ]

    [ one_side, twice, unseated, overspent ].each do |sides|
      assert_raises(ArgumentError) { Roll.quarrel!(campaign: @campaign, by: identities(:pip), sides: sides) }
    end
    assert_equal 1, @tibbs.reload.spark
  end

  test "a montage takes the highest result for the scene" do
    roll = Roll.montage!(campaign: @campaign, by: identities(:gwen), scene: "The climb",
      participants: [ { character: @tibbs }, { character: @bram } ], random: FixedDice.new([ 5, 2, 3, 1 ]))

    assert roll.montage?
    assert_equal "messy", roll.outcome, "Tibbs's messy beats Bram's grim"
    assert_equal [ "messy", "grim" ], roll.sides.pluck("outcome")
    assert_equal [ "The climb", "Gibbletibble \"Tibbs\" and Bram" ], [ roll.question, roll.name ]
  end

  test "spark in a montage adds dice to that character's roll" do
    roll = Roll.montage!(campaign: @campaign, by: identities(:pip),
      participants: [ { character: @tibbs, spend_spark: 1 }, { character: @bram } ], random: FixedDice.new([ 1, 2, 6, 6, 6 ]))

    assert_equal [ [ 1, 2, 6 ], [ 6, 6 ] ], roll.sides.pluck("dice")
    assert_equal [ false, true ], roll.sides.pluck("critical")
    assert_equal "perfect", roll.outcome
    assert_equal 0, @tibbs.reload.spark
  end

  test "montages stay within the rules" do
    [ [], [ { character: @tibbs }, { character: @tibbs } ], [ { character: characters(:loner) } ], [ { character: @tibbs, spend_spark: 2 } ] ].each do |participants|
      assert_raises(ArgumentError) { Roll.montage!(campaign: @campaign, by: identities(:pip), participants: participants) }
    end
    assert_equal 1, @tibbs.reload.spark
  end
end
