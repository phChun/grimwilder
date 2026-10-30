require "test_helper"

class ExpandedDowntimeTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @campaign.update!(optional_rules: [ "expanded_downtime" ])
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @tibbs.update!(marked_agility: true, bloodied: true, conditions: [ "4d poisoned", "lost an eye" ], spark: 0)
    @bram.update!(rattled: true, spark: 0)
    @gwen = identities(:gwen)
  end

  test "only those who rest heal, with the conditions the GM leaves ticked" do
    @campaign.downtime!(by: @gwen, clear: [ "#{@tibbs.id}:0", "#{@bram.id}:0" ], actions: { @tibbs.id.to_s => { "actions" => [ "rest" ] }, @bram.id.to_s => { "actions" => [ "unwind" ], "unwind" => "Sings at the inn" } })

    assert_not @tibbs.reload.bloodied?
    assert_equal [ "lost an eye" ], @tibbs.conditions.pluck("name")
    assert @bram.reload.rattled?, "unwinding doesn't heal"
    assert_equal 1, @bram.spark
    assert_equal "Downtime", @campaign.rolls.marker.last.name
    assert_equal "Bram unwinds; Tibbs rests.", @campaign.rolls.marker.last.question
    assert_equal "Bram unwinds: Sings at the inn.", @campaign.rolls.note.last.question
  end

  test "selling a treasure gives two different actions, and planning ahead keeps a thread until next time" do
    @campaign.downtime!(by: @gwen, actions: { @tibbs.id.to_s => { "actions" => [ "rest", "plan", "unwind" ], "plan" => "Borrows horses for a getaway" } })

    @tibbs.reload
    assert_not @tibbs.bloodied?
    assert_equal [ "Borrows horses for a getaway", 1 ], [ @tibbs.prep_note, @tibbs.prep_thread ]
    assert_equal 0, @tibbs.spark, "only the first two actions count"

    @tibbs.spend_plan_thread!(by: @tibbs.identity)
    assert_equal 0, @tibbs.reload.prep_thread
    assert_match "spends the thread from planning ahead", @campaign.rolls.note.last.question

    @campaign.downtime!(by: @gwen)
    assert_nil @tibbs.reload.prep_note, "lost when time passes again"
  end

  test "pursuing a goal makes its task pool the first time and rolls it each time" do
    @campaign.downtime!(by: @gwen, actions: { @tibbs.id.to_s => { "actions" => [ "goal" ], "goal_id" => "new", "goal_name" => "Cleanse the forest", "goal_size" => "6" } }, random: FixedDice.new([ 1, 2, 3, 4, 5, 6 ]))

    goal = @tibbs.goal_pools.sole
    assert_equal [ "Tibbs: Cleanse the forest", 6, 3, "task" ], [ goal.name, goal.starting_size, goal.size, goal.kind ]
    assert_not_includes @campaign.pools.talent, goal, "goals stay off the GM table's talent pools"

    @campaign.downtime!(by: @gwen, actions: { @tibbs.id.to_s => { "actions" => [ "goal" ], "goal_id" => goal.id.to_s } }, random: FixedDice.new([ 1, 1, 1 ]))
    assert goal.reload.depleted?

    PlaySession.start!(@campaign, characters: [ @tibbs ], by: @gwen)
    assert goal.reload.persisted?, "a session's talent refresh leaves goals alone"
  end

  test "venturing makes a story roll" do
    @campaign.downtime!(by: @gwen, actions: { @bram.id.to_s => { "actions" => [ "venture" ], "venture" => "Joins an expedition" } }, random: FixedDice.new([ 5, 2 ]))

    roll = @campaign.rolls.where(kind: "story").last
    assert_equal [ @bram, "Venture: Joins an expedition", "messy" ], [ roll.character, roll.question, roll.outcome ]
  end

  test "a plan or a new goal needs words" do
    assert_raises(ArgumentError) { @campaign.downtime!(by: @gwen, actions: { @tibbs.id.to_s => { "actions" => [ "plan" ] } }) }
    assert_raises(ArgumentError) { @campaign.downtime!(by: @gwen, actions: { @tibbs.id.to_s => { "actions" => [ "goal" ], "goal_id" => "new" } }) }
  end

  test "without the rule, downtime heals everyone as before and ignores actions" do
    @campaign.update!(optional_rules: [])
    @campaign.downtime!(by: @gwen, actions: { @tibbs.id.to_s => { "actions" => [ "unwind" ] } })

    assert_not @tibbs.reload.bloodied?
    assert_not @bram.reload.rattled?
    assert_equal 0, @tibbs.spark
  end

  test "carousing is gone while the rule is on" do
    @campaign.update!(optional_rules: [ "expanded_downtime", "wealth" ])
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: @gwen)
    assert @tibbs.reload.carousing_replaced?
    assert_raises(ArgumentError) { @tibbs.add_coins!(by: @gwen) }
  end
end
