require "test_helper"

class ExpandedDowntimeIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @campaign.update!(optional_rules: [ "expanded_downtime", "wealth" ])
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @tibbs.update!(bloodied: true)
  end

  test "the GM picks each character's action, and the sheet shows the plan and the goal" do
    sign_in_as identities(:gwen)
    get new_campaign_downtime_path(@campaign)
    assert_select ".downtime-pick", @campaign.resting_characters.size
    assert_select "select[name=?] option[value=goal]", "actions[#{@tibbs.id}][actions][]", 2

    post campaign_downtime_path(@campaign), params: { actions: {
      @tibbs.id.to_s => { actions: [ "plan", "goal" ], plan: "Scouts the old mill", goal_id: "new", goal_name: "Learn the old tongue", goal_size: "4" },
      @bram.id.to_s => { actions: [ "unwind", "" ], unwind: "Plays dice" }
    } }
    assert_response :redirect
    assert @tibbs.reload.bloodied?, "planning ahead doesn't heal"
    assert_equal "Scouts the old mill", @tibbs.prep_note
    assert_equal 1, @tibbs.goal_pools.count

    get character_path(@tibbs)
    assert_select ".rule-pools__plan", /Scouts the old mill/
    assert_select ".rule-pools__goal", /Learn the old tongue/
    assert_select "button", text: "+2d Coins: carousing", count: 0
  end

  test "the GM table's party cards list each character's goals to read" do
    @tibbs.talent_pools.create!(campaign: @campaign, goal: true, kind: "task", name: "Tibbs: Cleanse the well", starting_size: 4)
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".party-card__goals", "Goals: Cleanse the well · 4d"
    assert_select ".seat-pool__name", { text: "Cleanse the well", count: 0 }, "not a pool to roll there"
  end

  test "a new goal without a name sends the GM back to the form" do
    sign_in_as identities(:gwen)
    post campaign_downtime_path(@campaign), params: { actions: { @tibbs.id.to_s => { actions: [ "goal" ], goal_id: "new" } } }
    assert_redirected_to new_campaign_downtime_path(@campaign)
    assert_equal 0, @tibbs.goal_pools.count
  end

  test "the owner spends the plan-ahead thread and lets a goal go" do
    @tibbs.update!(prep_note: "Scouts the old mill", prep_thread: 1)
    goal = @tibbs.talent_pools.create!(campaign: @campaign, goal: true, kind: "task", name: "Tibbs: Learn the old tongue", starting_size: 4)
    sign_in_as @tibbs.identity

    delete character_plan_thread_path(@tibbs)
    assert_equal 0, @tibbs.reload.prep_thread

    delete character_goal_path(@tibbs, goal)
    assert_equal 0, @tibbs.goal_pools.count
  end
end
