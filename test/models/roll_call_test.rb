require "test_helper"

class RollCallTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, ActionCable::TestHelper, Turbo::Broadcastable::TestHelper

  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @pip, @gwen = identities(:pip), identities(:gwen)
  end

  test "a story roll call: the player's dice and thorns become the roll, and a disaster gives spark" do
    call = RollCall.story!(campaign: @campaign, by: @gwen, character: @tibbs, question: "Any guards?", odds: 1, thorns: 1)
    assert call.open?
    assert_empty @campaign.rolls.story

    call.roll!(@tibbs, by: @pip, spark: 1, random: FixedDice.new([ 1, 2, 7 ]))
    roll = call.reload.roll

    assert call.done?
    assert_equal [ 1, 2 ], roll.dice
    assert_equal [ 7 ], roll.thorns
    assert_equal "disaster", roll.outcome
    assert_equal [ 1, 1 ], [ roll.stat_dice, roll.spark_spent ]
    assert_equal @gwen, roll.identity, "the log credits whoever called it"
    assert_equal 1, @tibbs.reload.spark, "spent 1 to roll, took 1 for the disaster"
  end

  test "a story roll call with an assist: they roll 1d of their own, which counts" do
    call = RollCall.story!(campaign: @campaign, by: @gwen, character: @tibbs, odds: 1, thorns: 1, assists: [ @bram ])
    assert_equal [ 1, 1 ], call.seats.map { call.base_dice(_1) }

    call.roll!(@tibbs, by: @pip, random: FixedDice.new([ 2, 3 ]))
    call.roll!(@bram, by: @gwen, random: FixedDice.new([ 6 ]))
    roll = call.reload.roll
    assert_equal [ [ 2 ], [ 3 ], [ "Bram", 6 ], "perfect" ], [ roll.dice, roll.thorns, roll.assists.sole.values_at("name", "die"), roll.outcome ]
    assert_empty call.seats.last["thorns"], "the assist rolls no thorns"
    assert_match "Bram assisting", ApplicationController.helpers.roll_setup(roll)
  end

  test "a quarrel call: each side and each assist rolls, and the highest die wins" do
    call = RollCall.quarrel!(campaign: @campaign, by: @pip, stakes: "The map",
      sides: [ { character: @tibbs, helpers: [] }, { character: @bram, helpers: [] } ])
    call.roll!(@tibbs, by: @pip, random: FixedDice.new([ 3, 5 ]))
    assert_nil call.roll, "still waiting on Bram"

    call.roll!(@bram, by: @gwen, random: FixedDice.new([ 4, 2 ]))
    quarrel = call.reload.roll
    assert_equal @tibbs.name, quarrel.winner
    assert_equal [ [ 3, 5 ], [ 4, 2 ] ], quarrel.sides.pluck("dice")
  end

  test "an assist rolls 1d for its side, without spark" do
    @campaign.characters.create!(identity: @pip, name: "Fen", path: "Druid", brawn: 2, agility: 2, wits: 2, presence: 2, spark: 1)
    fen = @campaign.characters.find_by!(name: "Fen")
    call = RollCall.quarrel!(campaign: @campaign, by: @pip,
      sides: [ { character: @tibbs, helpers: [ fen ] }, { character: @bram, helpers: [] } ])

    assert_equal 1, call.base_dice(call.seats.find { _1["name"] == "Fen" })
    assert_raises(ArgumentError) { call.roll!(fen, by: @pip, spark: 1) }

    call.roll!(fen, by: @pip, random: FixedDice.new([ 6 ]))
    call.roll!(@tibbs, by: @pip, random: FixedDice.new([ 1, 2 ]))
    call.roll!(@bram, by: @gwen, random: FixedDice.new([ 5, 5 ]))

    quarrel = call.reload.roll
    assert_equal @tibbs.name, quarrel.winner, "Fen's 6 carries Tibbs"
    assert_equal [ { "name" => "Fen", "die" => 6 } ], quarrel.sides.first["helpers"].map { _1.slice("name", "die") }
  end

  test "only a character's player or the GM rolls for them, and only the player spends spark" do
    call = RollCall.montage!(campaign: @campaign, by: @pip, characters: [ @tibbs, @bram ])

    error = assert_raises(ArgumentError) { call.roll!(@bram, by: @pip) }
    assert_equal "Only Bram's player or the GM can roll for them.", error.message
    assert_raises(ArgumentError) { call.roll!(@tibbs, by: @gwen, spark: 1) }

    call.roll_everyone!(by: @gwen, random: FixedDice.new([ 4, 4, 2, 3 ]))
    assert_equal [ [ 4, 4 ], [ 2, 3 ] ], call.reload.seats.pluck("dice"), "every seat keeps its dice"
    assert_equal [ [ 4, 4 ], [ 2, 3 ] ], call.roll.sides.pluck("dice"), "and the montage is built from them"
    assert_equal "messy", call.roll.outcome
    assert_equal [ @gwen.display_name, nil ], call.seats.pluck("rolled_by"), "Bram is Gwen's own"
  end

  test "calls stay within the rules" do
    assert_raises(ArgumentError) { RollCall.montage!(campaign: @campaign, by: @pip, characters: []) }
    assert_raises(ArgumentError) { RollCall.quarrel!(campaign: @campaign, by: @pip, sides: [ { character: @tibbs, helpers: [] } ]) }
    assert_raises(ArgumentError) { RollCall.story!(campaign: @campaign, by: @pip, character: @tibbs, odds: 4) }
    assert_raises(ArgumentError) { RollCall.montage!(campaign: @campaign, by: @pip, characters: [ characters(:loner) ]) }

    RollCall.montage!(campaign: @campaign, by: @pip, characters: [ @tibbs ])
    assert_raises(ArgumentError) { RollCall.story!(campaign: @campaign, by: @gwen, character: @bram) }
  end

  test "calling it off gives back spent spark; only the caller or the GM can" do
    call = RollCall.montage!(campaign: @campaign, by: @gwen, characters: [ @tibbs, @bram ])
    call.roll!(@tibbs, by: @pip, spark: 1)
    assert_equal 0, @tibbs.reload.spark

    assert_raises(ArgumentError) { call.cancel!(by: @pip) }
    call.cancel!(by: @gwen)
    assert call.reload.cancelled?
    assert_equal 1, @tibbs.reload.spark
    assert_raises(ArgumentError) { call.roll!(@bram, by: @gwen) }
  end

  test "it shows to the people in it, and the result stays a little while" do
    call = RollCall.story!(campaign: @campaign, by: @pip, character: @tibbs)
    assert_equal call, RollCall.showing_for(@campaign, memberships(:pip_player))
    assert_equal call, RollCall.showing_for(@campaign, memberships(:gwen_gm))

    call.roll!(@tibbs, by: @pip)
    assert_equal call, RollCall.showing_for(@campaign, memberships(:pip_player))

    travel RollCall::RESULT_SHOWS_FOR + 1.second
    assert_nil RollCall.showing_for(@campaign, memberships(:pip_player))
  end

  test "each change swaps in a frame that loads each viewer's own copy" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :live ], count: 1 do
        RollCall.story!(campaign: @campaign, by: @pip, character: @tibbs)
      end
    end
    stream = capture_turbo_stream_broadcasts([ @campaign, :live ]).last
    assert_equal [ "update", @campaign.roll_call_slot_id ], [ stream["action"], stream["target"] ]
    frame = Nokogiri::HTML5.fragment(stream.at_css("template").inner_html).at_css("turbo-frame")
    assert_equal @campaign.roll_call_frame_id, frame["id"]
    assert_match %r{/campaigns/#{@campaign.id}/roll_call\?v=\d+}, frame["src"]
    assert_nil frame["data-turbo-permanent"], "Turbo would put a permanent frame back the way it was"
  end
end
