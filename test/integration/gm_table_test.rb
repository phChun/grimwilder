require "test_helper"

class GmTableTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "members get the table: who's here, pools, the log and the crucible frame" do
    characters(:tibbs).update!(bloodied: true, marked_agility: true, conditions: [ "4d poisoned" ])
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_response :success
    assert_select "details#table[open] .seat__name", text: characters(:tibbs).name
    assert_select "details#table .seat__chips .status-chip", text: "Bloodied"
    assert_select "details#table .seat__chips .status-chip", text: "Agility marked"
    assert_select "details#table .seat__chips .status-chip", text: "4d poisoned"
    assert_select "details#table .spark-dots[aria-label=?]", "1 of 2 spark"
    assert_select "details#table summary", /Gibbletibble "Tibbs" bloodied/
    assert_select "details#pools[open] .pool-row", 2, "lookouts and the brawl; the ambush is hidden"
    assert_select "details#roll-log #roll_log"
    assert_select "details#crucibles turbo-frame#crucible[src=?]", crucible_path(Crucible.grouped.first.last.first, embed: 1)
    assert_select "details#crucibles select#crucible-pick optgroup", Crucible.grouped.size
    assert_select "turbo-cable-stream-source", 3, "pool and table refreshes, plus the log"
  end

  test "players see a push badge, and a fold-out with drop-first and push" do
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    brawl = "##{dom_id(pools(:brawl))}"
    assert_select "#{brawl} .badge--push", "Nothing dropped: push?"
    assert_select "#{brawl} details.pool-row__more form[action=?]", campaign_pool_push_path(@campaign, pools(:brawl))
    assert_select "#{brawl} details.pool-row__more form[action=?] input[name=drop_first][value='1']", campaign_pool_roll_path(@campaign, pools(:brawl))
  end

  test "players can leave from settings but get no GM controls" do
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select "details#settings form[action=?]", campaign_membership_path(@campaign, memberships(:pip_player))
    assert_select "details#settings form[action=?][method=post] input[value=delete]", campaign_path(@campaign), count: 0
    assert_select "#pool-new", count: 0
    assert_select "button", text: "Copy join link", count: 0
  end

  test "the GM gets the join link, settings, pool controls and the new-pool form" do
    sign_in_as identities(:gwen)

    get campaign_path(@campaign)
    assert_select "button[data-controller=clipboard][data-clipboard-text-value=?]", join_url(@campaign.join_code), text: "Copy join link"
    assert_select "details#settings form[action=?]", campaign_join_code_path(@campaign)
    assert_select "details#pool-new:not([open]) form[action=?]", campaign_pools_path(@campaign)
    assert_select "##{dom_id(pools(:ambush))} .tag", "GM only"
    assert_select "##{dom_id(pools(:lookouts))} form[action=?]", campaign_pool_path(@campaign, pools(:lookouts))
  end

  test "a depleted pool dims, shows its outcome and offers the GM a reset" do
    pools(:lookouts).roll!(by: identities(:gwen), random: FixedDice.new([ 1, 1, 1, 1, 1, 1 ]))
    sign_in_as identities(:gwen)

    get campaign_path(@campaign)
    lookouts = "##{dom_id(pools(:lookouts))}"
    assert_select "#{lookouts}.pool-row--depleted .pool-row__outcome", "It arrives."
    assert_select "#{lookouts} .pool-row__primary form[action=?] button", campaign_pool_reset_path(@campaign, pools(:lookouts)), text: "Reset to 6d"
  end

  test "a new pool that doesn't save shows the table again, form open" do
    sign_in_as identities(:gwen)

    post campaign_pools_path(@campaign), params: { pool: { name: "", starting_size: 4 } }
    assert_response :unprocessable_entity
    assert_select "details#pool-new[open] .form-error", /Name can't be blank/
    assert_select "details#pools .pool-row", 3
  end

  test "a crucible embeds in the table's frame" do
    get crucible_path("gm", embed: 1)
    assert_response :success
    assert_select "turbo-frame#crucible [data-controller=crucible][data-crucible-key-value=gm]"
    assert_select "turbo-frame#crucible [data-crucible-target=table]", 2

    get crucible_path("gm")
    assert_select "turbo-frame#crucible", count: 0
    assert_select "h1", "GM crucible"
  end
end
