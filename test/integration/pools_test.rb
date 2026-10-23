require "test_helper"

class PoolsTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "the GM adds a pool" do
    sign_in_as identities(:gwen)

    assert_difference -> { @campaign.pools.count }, 1 do
      post campaign_pools_path(@campaign), params: { pool: { name: "Reinforcements arrive", kind: "pressure", starting_size: 8 } }
    end
    pool = @campaign.pools.find_by!(name: "Reinforcements arrive")
    assert_redirected_to campaign_table_path(@campaign, anchor: dom_id(pool))
    assert_equal 8, pool.size
  end

  test "the old pools page sends you to the campaign's pools" do
    sign_in_as identities(:pip)

    get campaign_pools_path(@campaign)
    assert_redirected_to campaign_path(@campaign, anchor: "pools")
  end

  test "a player sees visible pools only, and no GM controls" do
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_response :success
    assert_select "#pools .pool-row__name", text: "Lookouts spot you"
    assert_select "#pools .pool-row__name", text: "Goblin ambush", count: 0
    assert_select "#pool-new", count: 0
    assert_select "form[action=?]", campaign_pool_reset_path(@campaign, pools(:brawl)), count: 0
    assert_select "form[action=?]", campaign_pool_path(@campaign, pools(:lookouts)), count: 0
    assert_select "form[action=?]", campaign_join_code_path(@campaign), count: 0
    assert_select "button[data-controller=clipboard]", count: 0, text: "Copy join link"

    post campaign_pools_path(@campaign), params: { pool: { name: "Mine", starting_size: 2 } }
    assert_response :forbidden
  end

  test "a player rolls a pool" do
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, pools(:lookouts))
    assert_redirected_to campaign_path(@campaign, anchor: "pool_#{pools(:lookouts).id}")
    assert_equal identities(:pip), pools(:lookouts).reload.last_rolled_by
  end

  test "a player can't roll a hidden pool" do
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, pools(:ambush))
    assert_response :not_found
  end

  test "push a task roll that dropped nothing" do
    sign_in_as identities(:pip)

    post campaign_pool_push_path(@campaign, pools(:brawl))
    assert_equal 3, pools(:brawl).reload.size
  end

  test "only the GM resets, hides and deletes" do
    sign_in_as identities(:pip)
    post campaign_pool_reset_path(@campaign, pools(:brawl))
    assert_response :forbidden

    sign_out
    sign_in_as identities(:gwen)
    patch campaign_pool_path(@campaign, pools(:lookouts)), params: { pool: { hidden: true } }
    assert pools(:lookouts).reload.hidden?

    assert_difference -> { Pool.count }, -1 do
      delete campaign_pool_path(@campaign, pools(:lookouts))
    end

    follow_redirect!
    assert_select ".toasts .toast.toast--notice[role=status] .toast__message", "#{pools(:lookouts).name} removed."
    assert_select ".flash", 0, "a toast, not a banner"
  end

  test "outsiders get a 404" do
    sign_in_as identities(:stranger)

    get campaign_pools_path(@campaign)
    assert_response :not_found
  end

  test "/pools opens your latest campaign's pools" do
    sign_in_as identities(:gwen)

    get pools_path
    assert_redirected_to campaign_table_path(@campaign, anchor: "pools")
  end

  test "roll a power pool as an action, spending your own character's spark" do
    wand = @campaign.pools.create!(name: "Blasting Wand", kind: "power", starting_size: 4)
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select "##{dom_id(wand)} .pool-row__action-roll select[name=character_id] option", 2, "no one, or Tibbs"
    assert_select "##{dom_id(pools(:lookouts))} .pool-row__action-roll", 0

    post campaign_pool_roll_path(@campaign, wand), params: { as_action: "1", thorns: 1, character_id: characters(:tibbs).id, spark: 1 }
    assert_redirected_to campaign_path(@campaign, anchor: dom_id(wand))
    roll = wand.rolls.last
    assert_equal [ 5, 1, 1 ], [ roll.dice.size, roll.thorns.size, roll.spark_spent ]

    follow_redirect!
    assert_select "##{dom_id(roll)} .roll-result__word", roll.critical? ? "Critical" : roll.outcome.capitalize
    assert_select "##{dom_id(roll)} .feed-item__meta", /4d \+ 1 spark, vs 1t as an action for Gibbletibble "Tibbs"/
    assert_select "##{dom_id(roll)} .die--spark", 1
  end

  test "you can't spend another player's character's spark on a pool" do
    wand = @campaign.pools.create!(name: "Blasting Wand", kind: "power", starting_size: 4)
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, wand), params: { as_action: "1", character_id: characters(:bram).id, spark: 1 }
    assert_response :not_found
    assert_equal 4, wand.reload.size
  end

  test "a bad action roll on a pool goes back with the reason" do
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, pools(:lookouts)), params: { as_action: "1" }
    assert_equal "Only a power pool is rolled as an action.", flash[:alert]
    assert_equal 6, pools(:lookouts).reload.size
  end

  test "the GM adds a linked pool, and the table sees its phases" do
    sign_in_as identities(:gwen)

    post campaign_pools_path(@campaign), params: { pool: { name: "Ogre", kind: "task", starting_size: 4, phases_text: "2d Claws + 4d Body" } }
    ogre = @campaign.pools.find_by!(name: "Ogre")
    assert_equal [ 2, "Claws" ], [ ogre.size, ogre.phase_name ]

    ogre.roll!(by: identities(:gwen), random: FixedDice.new([ 1, 3 ]))
    get campaign_table_path(@campaign)
    assert_select "##{dom_id(ogre)} .pool__phase--done", "2d Claws"
    assert_select "##{dom_id(ogre)} .pool__phase--current[aria-current=step]", "4d Body"
    assert_select "#table_feed .feed-item__meta", /0d: Claws is done\. 4d Body begins\./
  end

  test "badly written phases show the form again, as typed" do
    sign_in_as identities(:gwen)

    post campaign_pools_path(@campaign), params: { pool: { name: "Ogre", starting_size: 4, phases_text: "4d Claws + Tail" } }
    assert_response :unprocessable_entity
    assert_select ".form-error", /Phases should be two or more/
    assert_select "input[name='pool[phases_text]'][value=?]", "4d Claws + Tail"
  end

  test "a player can drop 1d first only on a task pool" do
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, pools(:lookouts)), params: { drop_first: "1" }
    assert_redirected_to campaign_path(@campaign, anchor: dom_id(pools(:lookouts)))
    assert_nil pools(:lookouts).reload.last_action

    post campaign_pool_roll_path(@campaign, pools(:brawl)), params: { drop_first: "1" }
    assert_equal "rolled_after_drop", pools(:brawl).reload.last_action
  end
end
