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

    assert_select ".scene-bar__actions > .tally--suspense:first-child[aria-label=?]", "Suspense, players can see it"
    assert_select "#table .tally--suspense", 0, "suspense sits with the session controls, not the party"
    assert_select ".tally--suspense .pips", 0, "just the count"
    assert_select ".tally--suspense .tally__count", "0 suspense left" # session 1 adds none
    assert_select ".tally--suspense button[aria-label=?][disabled]", "Spend 1 suspense (prompts an impact move)", text: "−"
    assert_select ".tally--suspense button[aria-label=?]", "Gain 1 suspense", text: "+"
    assert_select "aside.gm-view__side > .table-rail + section#kept_crucibles.side-card[data-turbo-permanent][hidden]", 1, "under the chat, as on the campaign page"
    assert_select ".scene-bar__actions > *:nth-child(2)", "Cut to new scene"
    assert_select ".scene-bar__actions > *:nth-child(3)", "Scene prep"
    assert_select ".scene-bar__actions > *:nth-child(4)", "End session"

    assert_select ".party-card a[href=?]", character_path(characters(:tibbs)), characters(:tibbs).name
    assert_select ".party-card__harm", "Bloodied · Agility marked · 4d poisoned"
    assert_select ".party-card__currency", "Spark 1 · Thread 3" # Mastermind: 3 thread a session
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

  test "a party card says what a character still has to pick" do
    tibbs = characters(:tibbs) # level 1, one talent, no Expertise skills picked
    tibbs.update!(level: 2)
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".party-card__picks", text: "Picks to make: 1 talent, 3 skills (Expertise)"

    tibbs.update!(level: 1)
    tibbs.choose_for_talent!("expertise", "skills" => %w[ charm stealth network ])
    get campaign_table_path(@campaign)
    assert_select ".party-card__picks", text: /Expertise/, count: 0
  end

  test "under Rest resets, the Reset form lets the GM pick conditions that fade" do
    @campaign.update!(optional_rules: %w[ rest_resets ])
    characters(:tibbs).update!(conditions: [ "cursed" ])
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "a[href=?]", new_campaign_rest_reset_path(@campaign), text: "Reset"

    get new_campaign_rest_reset_path(@campaign)
    assert_select "input[type=checkbox][name='clear[]']:not([checked])"
    post campaign_rest_reset_path(@campaign), params: { clear: [ "#{characters(:tibbs).id}:0" ] }
    assert_empty characters(:tibbs).reload.conditions
  end

  test "Wealth: the owner adds 2d of Coins from the sheet" do
    @campaign.update!(optional_rules: %w[ wealth ])
    tibbs = characters(:tibbs)
    sign_in_as identities(:pip)
    get character_path(tibbs)
    assert_select ".rule-pools form[action=?] button", character_coins_path(tibbs), text: "+2d Coins: carousing"

    post character_coins_path(tibbs)
    assert_equal 6, tibbs.talent_pools.find_by!(use_key: "rule/coins").size
  end

  test "the GM prepares scenes, then starts one from the prep, filled in" do
    sign_in_as identities(:gwen)
    get campaign_scene_plans_path(@campaign)
    assert_response :success

    post campaign_scene_plans_path(@campaign), params: { scene_plan: { title: "The bridge at Mirefall", notes: "Toll-keepers want a bribe.", opening_odds: "3", opening_question: "Is the bridge guarded?" } }
    plan = @campaign.scene_plans.sole
    assert_redirected_to campaign_scene_plans_path(@campaign)

    PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: identities(:gwen))
    get new_campaign_scene_path(@campaign)
    assert_select ".scene-prep-picks a[href=?]", new_campaign_scene_path(@campaign, plan: plan.id), "The bridge at Mirefall"

    get new_campaign_scene_path(@campaign, plan: plan.id)
    assert_select "input#scene_title[value=?]", "The bridge at Mirefall"
    assert_select "textarea#scene_notes", "Toll-keepers want a bribe."
    assert_select "details.scene-form__opening[open]"
    assert_select "input#scene_open_with_story[checked]"
    assert_select "input#story_question[value=?]", "Is the bridge guarded?"
    assert_select "input[name=odds][value='3'][checked]"

    post campaign_scenes_path(@campaign), params: { scene_plan_id: plan.id, title: "The bridge at Mirefall", notes: "Toll-keepers want a bribe.", open_with_story: "1", question: "Is the bridge guarded?", odds: "3" }
    scene = @campaign.reload.current_scene
    assert_equal [ "The bridge at Mirefall", "Toll-keepers want a bribe.", scene ], [ scene.title, scene.notes, plan.reload.scene ]
    assert_equal [ 3, "Is the bridge guarded?" ], [ scene.opening_roll.stat_dice, scene.opening_roll.question ]
    assert_empty @campaign.scene_plans.unplayed, "a plan once played leaves the list"
  end

  test "only the GM preps scenes" do
    sign_in_as identities(:pip)
    get campaign_scene_plans_path(@campaign)
    assert_response :forbidden
  end
end
