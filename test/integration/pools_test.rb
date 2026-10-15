require "test_helper"

class PoolsTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "the GM adds a pool" do
    sign_in_as identities(:gwen)

    assert_difference -> { @campaign.pools.count }, 1 do
      post campaign_pools_path(@campaign), params: { pool: { name: "Reinforcements arrive", kind: "pressure", starting_size: 8 } }
    end
    assert_redirected_to campaign_pools_path(@campaign)
    assert_equal 8, @campaign.pools.find_by!(name: "Reinforcements arrive").size
  end

  test "a player sees visible pools only, and can't add one" do
    sign_in_as identities(:pip)

    get campaign_pools_path(@campaign)
    assert_response :success
    assert_select "h2", text: "Lookouts spot you"
    assert_select "h2", text: "Goblin ambush", count: 0
    assert_select "#pool-new", count: 0

    post campaign_pools_path(@campaign), params: { pool: { name: "Mine", starting_size: 2 } }
    assert_response :forbidden
  end

  test "a player rolls a pool" do
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, pools(:lookouts))
    assert_redirected_to campaign_pools_path(@campaign, anchor: "pool_#{pools(:lookouts).id}")
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
  end

  test "outsiders get a 404" do
    sign_in_as identities(:stranger)

    get campaign_pools_path(@campaign)
    assert_response :not_found
  end

  test "the nav's Pools link opens your latest campaign's pools" do
    sign_in_as identities(:gwen)

    get pools_path
    assert_redirected_to campaign_pools_path(@campaign)
  end
end
