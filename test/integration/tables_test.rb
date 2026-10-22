require "test_helper"

# The GM table (campaigns/tables#show): the scene and suspense, the party,
# pools as cards, the crucible and the table's rail. GM only.
class TablesTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "only the GM gets the table" do
    sign_in_as identities(:pip)
    get campaign_table_path(@campaign)
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    get campaign_table_path(@campaign)
    assert_response :not_found
  end

  test "the scene, suspense and the party" do
    session = PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: identities(:gwen))
    Scene.start!(session, title: "The mill fire", by: identities(:gwen))
    characters(:tibbs).update!(bloodied: true, marked_agility: true, conditions: [ "4d poisoned" ])
    @campaign.memberships.create!(identity: identities(:stranger), role: :player)
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_response :success
    assert_select ".tabs__link[aria-current=page]", "Table"
    assert_select ".live-banner", 0, "already at the table"

    assert_select ".scene-bar__status", /Session 1 · live \d+m · Scene 1 of 1/
    assert_select "h1.scene-bar__title", "The mill fire"
    assert_select ".scene-bar__actions a", text: /Story roll|Montage|Quarrel/, count: 0
    assert_select "details#rolls summary", "Rolls"
    assert_select "#rolls .rolls__kinds input[name=roll_kind]", 3
    assert_select "#rolls form[action=?]", campaign_story_rolls_path(@campaign)
    assert_select "#rolls form[action=?]", campaign_montages_path(@campaign)
    assert_select "#rolls form[action=?]", campaign_quarrels_path(@campaign)
    assert_select ".scene-bar__actions a[href=?]", new_campaign_play_session_ending_path(@campaign, session), "End session"

    assert_select "#table .party-grid > .suspense-panel:first-child .suspense-panel__note", "players can see it"
    assert_select ".scene-bar .suspense-panel", 0, "suspense sits with the party, not the scene"
    assert_select ".suspense-panel__value[aria-label=?]", "0 suspense", text: "0" # session 1 adds none
    assert_select ".suspense-panel button[aria-label=?][disabled]", "Spend 1 suspense", text: /Spend/
    assert_select ".suspense-panel button[aria-label=?]", "Gain 1 suspense", text: /Gain/

    assert_select ".party-card a[href=?]", character_path(characters(:tibbs)), characters(:tibbs).name
    assert_select ".party-card__harm", "Bloodied · Agility marked · 4d poisoned"
    assert_select ".party-card__currency", "Spark 1 · Thread 3" # According to Plan: 3 thread a session
    assert_select ".party-card--empty .party-card__name", "Stranger"
    assert_select ".party-card--empty .party-card__meta", "Making a character"
  end

  test "pools are cards: hidden ones are dashed purple with Reveal, and the last roll shows its dice" do
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)

    assert_select "#pools .pool-card", 3
    ambush = "##{dom_id(pools(:ambush))}"
    assert_select "#{ambush}.pool-card--hidden .pool-card__meta", "Timer · hidden from players"
    assert_select "#{ambush} .pool-card__meta svg.icon--eye-off"
    assert_select "#{ambush} button.button--suspense", "Roll 4d"
    assert_select "#{ambush} button", "Reveal"
    assert_select "#{ambush} .pool-track--hidden .pool-track__segment--full", 4

    brawl = "##{dom_id(pools(:brawl))}"
    assert_select "#{brawl} .pool-card__dice .die", 4
    assert_select "#{brawl} .pool-card__change", /4d → 4d · 5 minutes ago · nothing dropped/
    assert_select "#{brawl} button.button--primary", "Roll 4d"
    assert_select "#{brawl} summary[aria-label=?]", "More for Barroom brawl"
    assert_select "#{brawl} .pool-card__menu button", "Push (take a mark)"

    patch campaign_pool_path(@campaign, pools(:ambush)), params: { pool: { hidden: false } }
    assert_redirected_to campaign_table_path(@campaign, anchor: dom_id(pools(:ambush)))
    assert_not pools(:ambush).reload.hidden?
  end

  test "an empty resource pool says so and offers a restock" do
    food = @campaign.pools.create!(name: "Food supplies", kind: "resource", starting_size: 4)
    food.update!(size: 0, last_action: "rolled", last_dice: [ 1, 2 ], last_dropped: 2, last_rolled_at: 20.minutes.ago)
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    card = "##{dom_id(food)}"
    assert_select "#{card}.pool-card--empty .pool-card__outcome", "All gone."
    assert_select "#{card} .pool-card__meta", "Resource · ran out 20 minutes ago"
    assert_select "#{card} button", "Restock to 4d"

    post campaign_pool_reset_path(@campaign, food)
    assert_equal 4, food.reload.size
  end

  test "cut to a new scene: end this one, then start the next" do
    session = PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: identities(:gwen))
    scene = Scene.start!(session, title: "The mill fire", by: identities(:gwen))
    sign_in_as identities(:gwen)

    get new_campaign_scene_ending_path(@campaign, scene, then: "new_scene")
    assert_select "input[type=hidden][name=then][value=new_scene]"
    assert_select "button[type=submit]", "End it and start the next scene"

    post campaign_scene_ending_path(@campaign, scene), params: { then: "new_scene" }
    assert_redirected_to new_campaign_scene_path(@campaign)
    assert_not scene.reload.open?
  end

  test "the rail has the feed, the composer and a note box" do
    @campaign.messages.create!(identity: identities(:pip), body: "Ready.")
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".table-rail #table_feed"
    assert_select ".table-rail form[action=?]", campaign_notes_path(@campaign)
    assert_select ".table-rail #table_feed .chat-line__body", "Ready."
    assert_select "details#crucibles summary .gm-section__title", "Crucible"
    assert_select "details#crucibles turbo-frame#crucible[loading=lazy]"
  end
end
