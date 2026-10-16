require "test_helper"

class PoolTest < ActiveSupport::TestCase
  setup { @pool = pools(:lookouts) }

  test "a new pool starts full" do
    pool = campaigns(:bramblewood).pools.create!(name: "Sunrise", kind: "timer", starting_size: 8)
    assert_equal 8, pool.size
  end

  test "rolling drops every die showing 1-3" do
    @pool.roll!(by: identities(:gwen), random: FixedDice.new([ 1, 2, 3, 4, 5, 6 ]))

    assert_equal 3, @pool.size
    assert_equal 3, @pool.last_dropped
    assert_equal [ 1, 2, 3, 4, 5, 6 ], @pool.last_dice
    assert_equal identities(:gwen), @pool.last_rolled_by
  end

  test "dropping 1d first rolls one die fewer" do
    @pool.roll!(by: identities(:gwen), drop_first: true, random: FixedDice.new([ 6, 6, 6, 6, 6 ]))

    assert_equal 5, @pool.size
    assert_equal 1, @pool.last_dropped
    assert_equal "rolled_after_drop", @pool.last_action
  end

  test "at 0d the event happens and the pool can't roll" do
    @pool.roll!(by: identities(:gwen), random: FixedDice.new([ 1, 1, 1, 1, 1, 1 ]))

    assert @pool.depleted?
    assert_equal "It arrives.", @pool.outcome
    assert_raises(ArgumentError) { @pool.roll!(by: identities(:gwen)) }
  end

  test "only a task roll that dropped nothing can be pushed" do
    brawl = pools(:brawl)
    assert brawl.pushable?

    brawl.push!(by: identities(:pip))
    assert_equal 3, brawl.size
    assert_equal "pushed", brawl.last_action
    assert_not brawl.pushable?

    @pool.roll!(by: identities(:gwen), random: FixedDice.new([ 6, 6, 6, 6, 6, 6 ]))
    assert_not @pool.pushable?, "pressure pools can't be pushed"
  end

  test "reset refills the pool and clears the last roll" do
    @pool.roll!(by: identities(:gwen), random: FixedDice.new([ 1, 1, 6, 6, 6, 6 ]))
    @pool.reset!

    assert_equal 6, @pool.size
    assert_empty @pool.last_dice
    assert_not @pool.resettable?
  end

  test "every roll, drop-first and push goes in the campaign log" do
    brawl = pools(:brawl)

    assert_difference -> { campaigns(:bramblewood).rolls.pool.count }, 3 do
      brawl.roll!(by: identities(:pip), random: FixedDice.new([ 4, 5, 6, 6 ]))
      brawl.push!(by: identities(:pip))
      brawl.roll!(by: identities(:pip), drop_first: true, random: FixedDice.new([ 1, 6 ]))
    end

    rolled, pushed, dropped_first = brawl.rolls.order(:id).last(3)
    assert_equal [ "rolled", [ 4, 5, 6, 6 ], 0, 4 ], rolled.values_at(:pool_action, :dice, :dropped, :remaining)
    assert_equal [ "pushed", [], 1, 3 ], pushed.values_at(:pool_action, :dice, :dropped, :remaining)
    assert_equal [ "rolled_after_drop", [ 1, 6 ], 2, 1 ], dropped_first.values_at(:pool_action, :dice, :dropped, :remaining)
    assert_equal "Barroom brawl", rolled.name
  end

  test "rolls on a hidden pool are for the GM only" do
    roll = pools(:ambush).roll!(by: identities(:gwen))

    assert roll.gm_only?
    assert_includes Roll.visible_to(memberships(:gwen_gm)), roll
    assert_not_includes Roll.visible_to(memberships(:pip_player)), roll
  end

  test "a power pool rolls as an action: highest die is the result, then 1-3s drop" do
    wand = campaigns(:bramblewood).pools.create!(name: "Blasting Wand", kind: "power", starting_size: 4)
    tibbs = characters(:tibbs)

    roll = wand.roll!(by: identities(:pip), as_action: true, thorns: 1, character: tibbs, spend_spark: 1,
      random: FixedDice.new([ 5, 2, 1, 4, 6, 3 ]))

    assert_equal 2, wand.size, "the 2 and 1 drop; the spark die never joins the pool"
    assert_equal [ 5, 2, 1, 4 ], wand.last_dice
    assert_equal [ [ 5, 2, 1, 4, 6 ], [ 3 ] ], [ roll.dice, roll.thorns ]
    assert_equal [ "perfect", 2, 1 ], [ roll.outcome, roll.dropped, roll.spark_spent ]
    assert_equal 0, tibbs.reload.spark
  end

  test "a disaster on a power pool gives its character spark" do
    wand = campaigns(:bramblewood).pools.create!(name: "Blasting Wand", kind: "power", starting_size: 2)

    roll = wand.roll!(by: identities(:pip), as_action: true, thorns: 1, character: characters(:tibbs), random: FixedDice.new([ 2, 3, 8 ]))
    assert_equal "disaster", roll.outcome
    assert roll.spark_gained?
    assert_equal 2, characters(:tibbs).reload.spark
    assert wand.depleted?
  end

  test "only power pools roll as an action, and only action rolls take thorns and spark" do
    wand = campaigns(:bramblewood).pools.create!(name: "Blasting Wand", kind: "power", starting_size: 4)

    assert_raises(ArgumentError) { @pool.roll!(by: identities(:gwen), as_action: true) }
    assert_raises(ArgumentError) { wand.roll!(by: identities(:gwen), thorns: 1) }
    assert_raises(ArgumentError) { wand.roll!(by: identities(:gwen), as_action: true, spend_spark: 1) }
    assert_raises(ArgumentError) { wand.roll!(by: identities(:gwen), as_action: true, character: characters(:loner)) }
    assert_raises(ArgumentError) { wand.roll!(by: identities(:pip), as_action: true, character: characters(:tibbs), spend_spark: 2) }
    assert_equal 4, wand.reload.size
  end

  test "players don't see hidden pools" do
    assert_includes Pool.visible_to(memberships(:gwen_gm)), pools(:ambush)
    assert_not_includes Pool.visible_to(memberships(:pip_player)), pools(:ambush)
  end

  test "size is limited to 1-20 dice" do
    assert_not Pool.new(campaign: campaigns(:bramblewood), name: "Too big", starting_size: 21).valid?
    assert_not Pool.new(campaign: campaigns(:bramblewood), name: "Empty", starting_size: 0).valid?
  end
end
