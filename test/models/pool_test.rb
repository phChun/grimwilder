require "test_helper"

class PoolTest < ActiveSupport::TestCase
  # Stands in for Random: returns the given dice in order.
  FixedDice = Struct.new(:faces) do
    def rand(_range) = faces.shift
  end

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

  test "players don't see hidden pools" do
    assert_includes Pool.visible_to(memberships(:gwen_gm)), pools(:ambush)
    assert_not_includes Pool.visible_to(memberships(:pip_player)), pools(:ambush)
  end

  test "size is limited to 1-20 dice" do
    assert_not Pool.new(campaign: campaigns(:bramblewood), name: "Too big", starting_size: 21).valid?
    assert_not Pool.new(campaign: campaigns(:bramblewood), name: "Empty", starting_size: 0).valid?
  end
end
