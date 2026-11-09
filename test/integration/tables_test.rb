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

    assert_select ".scene-bar__status", /Session 1 · live · Scene 1 of 1/
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
    # The fixture's "5 minutes ago" is from when fixtures loaded, which can be over 30s ago by now.
    pools(:brawl).update_columns(last_rolled_at: 5.minutes.ago)
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

  test "cut to a new scene: end this one in a modal, then start the next in another" do
    session = PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: identities(:gwen))
    scene = Scene.start!(session, title: "The mill fire", by: identities(:gwen))
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".scene-bar a[href=?][data-turbo-frame=modal]", new_campaign_scene_ending_path(@campaign, scene, then: "new_scene"), "Cut to new scene"
    get new_campaign_scene_ending_path(@campaign, scene, then: "new_scene")
    assert_select "turbo-frame#modal form[action=?][data-turbo-frame=_top]", campaign_scene_ending_path(@campaign, scene) do
      assert_select "input[type=hidden][name=then][value=new_scene]"
      assert_select "button[type=submit]", "End it and start the next scene"
    end

    # A montage called from the modal stays in it, and comes back to ending the scene.
    montage = new_campaign_montage_path(@campaign, then: "end_scene", scene: "The mill fire", cut: 1)
    assert_select "turbo-frame#modal a[href=?]:not([data-turbo-frame])", montage, "Call for a montage"
    get montage
    assert_select "turbo-frame#modal form[action=?][data-modal-stay]:not([data-turbo-frame])", campaign_montages_path(@campaign) do
      assert_select "input[type=hidden][name=then][value=end_scene]"
      assert_select "input[type=hidden][name=cut][value='1']"
    end
    post campaign_montages_path(@campaign), params: { then: "end_scene", cut: "1", scene: "The mill fire", participants: { characters(:tibbs).id => { in: "1" } } }
    assert_redirected_to new_campaign_scene_ending_path(@campaign, scene, then: "new_scene")
    follow_redirect!
    assert_select "turbo-frame#modal a[href=?]", new_campaign_scene_ending_path(@campaign, scene, then: "new_scene"), "Check again"
    assert_select "a", { text: "Call for a montage", count: 0 }, "one montage at a time"

    post campaign_scene_ending_path(@campaign, scene), params: { then: "new_scene" }
    assert_redirected_to campaign_table_path(@campaign, anchor: "roll-log")
    assert_not scene.reload.open?
    follow_redirect!
    assert_select "[data-controller=modal-opener][data-modal-opener-url-value=?]", new_campaign_scene_path(@campaign)
  end

  test "the rail has the feed, the composer and a note box" do
    @campaign.messages.create!(identity: identities(:pip), body: "Ready.")
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".table-rail #table_feed"
    assert_equal [ "Narrate", "As NPC" ], css_select(".table-rail .composer .segmented__text").map(&:text)
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

  test "the GM adds scenes inline, then starts one, adjusted, and the story roll opens with its question" do
    sign_in_as identities(:gwen)
    get campaign_scene_plans_path(@campaign)
    assert_select ".fluid__rail", 0, "no side panel for new things"
    assert_select ".scene-prep__tools button[data-action='details-memory#foldAll']", 2
    assert_select "details#scene_plans_loose.sheet-fold[open] .sheet-fold__title", /Standalone scenes/
    assert_select "details#scene_plans_loose .scene-collection__actions turbo-frame#new_scene_plan_standalone a[href=?]", new_campaign_scene_plan_path(@campaign), "Add a scene"
    assert_select "#scene_collections_title", "Scene collections"
    assert_select ".scene-prep__more > turbo-frame#new_scene_collection:first-child a.add-card[href=?]", new_campaign_scene_collection_path(@campaign), /Create new scene collection/
    assert_select ".scene-prep__more > turbo-frame#new_scene_collection + details#scene_plans_loose"

    get new_campaign_scene_plan_path(@campaign)
    assert_select "turbo-frame#new_scene_plan_standalone form[action=?][data-turbo-frame=_top]", campaign_scene_plans_path(@campaign) do
      assert_select "input[name='scene_plan[story_question]']"
      assert_select "input[name='scene_plan[opening_odds]']", 0
      assert_select ".scene-plan-form__actions input[type=submit][value='Add scene'] + a.button--danger[href=?][data-turbo-frame=new_scene_plan_standalone]", campaign_scene_plans_path(@campaign), text: "Cancel"
    end

    post campaign_scene_plans_path(@campaign), params: { scene_plan: { title: "The bridge at Mirefall", notes: "Toll-keepers want a bribe.", story_question: "Is the bridge guarded?" } }
    plan = @campaign.scene_plans.sole
    assert_redirected_to campaign_scene_plans_path(@campaign, anchor: "scene_plan_#{plan.id}")
    post campaign_scene_plans_path(@campaign), params: { scene_plan: { title: " " } }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#new_scene_plan_standalone .form-error"

    PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: identities(:gwen))
    get new_campaign_scene_path(@campaign)
    assert_select ".scene-picker .scene-plans__title", "The bridge at Mirefall"
    assert_select ".scene-picker .field__hint", "Story roll: Is the bridge guarded?"
    assert_select ".scene-picker a[href=?]", new_campaign_scene_path(@campaign, plan: plan.id, anchor: "scene_title"), "Adjust first"
    assert_select ".scene-picker a[aria-label=?]", "Adjust The bridge at Mirefall first"

    get new_campaign_scene_path(@campaign, plan: plan.id)
    assert_select "input#scene_title[value=?]", "The bridge at Mirefall"
    assert_select "textarea#scene_notes", "Toll-keepers want a bribe."
    assert_select "input#scene_story_question[value=?]", "Is the bridge guarded?"
    assert_select "input[name=odds]", 0, "the odds are picked in the story roll"

    post campaign_scenes_path(@campaign), params: { scene_plan_id: plan.id, title: "The bridge at Mirefall", notes: "Toll-keepers want a bribe.", story_question: "Is the bridge watched?" }
    scene = @campaign.reload.current_scene
    assert_equal [ "The bridge at Mirefall", "Toll-keepers want a bribe.", "Is the bridge watched?", scene ], [ scene.title, scene.notes, scene.story_question, plan.reload.scene ]
    assert_nil scene.opening_roll, "nothing's rolled until the GM rolls it"
    assert_empty @campaign.scene_plans.unplayed, "a plan once played leaves the list"

    follow_redirect!
    story = new_campaign_story_roll_path(@campaign, question: "Is the bridge watched?")
    assert_select "[data-controller=modal-opener][data-modal-opener-url-value=?]", story
    assert_select ".scene-bar__question a[href=?][data-turbo-frame=modal]", story, "Roll it"
    get campaign_table_path(@campaign)
    assert_select "[data-controller=modal-opener]", 0, "it opens once"

    get story
    assert_select "turbo-frame#modal form.story-roll[action=?][data-turbo-frame=_top]", campaign_story_rolls_path(@campaign) do
      assert_select "input#modal_story_question[value=?]", "Is the bridge watched?"
      assert_select "input[name=odds][value='2'][checked]"
      assert_select "select#modal_story_character option", 3, "no one in particular, Tibbs or Bram"
    end

    post campaign_story_rolls_path(@campaign), params: { question: "Is the bridge watched?", odds: "3" }
    assert_equal [ 3, "Is the bridge watched?" ], [ scene.reload.opening_roll.stat_dice, scene.opening_roll.question ]
    get campaign_table_path(@campaign)
    assert_select ".scene-bar__question", 0, "rolled, so it's gone from the bar"
  end

  test "the GM groups scenes in collections; starting a scene offers each collection, then the standalone ones" do
    sign_in_as identities(:gwen)
    get new_campaign_scene_collection_path(@campaign)
    assert_select "turbo-frame#new_scene_collection form[action=?]", campaign_scene_collections_path(@campaign) do
      assert_select "a.button--danger[href=?][data-turbo-frame=new_scene_collection]", campaign_scene_plans_path(@campaign), "Cancel"
    end
    post campaign_scene_collections_path(@campaign), params: { scene_collection: { title: "The castle", notes: "The baron is away." } }
    castle = @campaign.scene_collections.sole
    assert_redirected_to campaign_scene_plans_path(@campaign, anchor: "scene_collection_#{castle.id}")

    get campaign_scene_plans_path(@campaign)
    assert_select "details#scene_collection_#{castle.id}.sheet-fold:not([open])", 1, "collections start closed"
    assert_select "details#scene_collection_#{castle.id}" do
      assert_equal [ "Add a scene", "Edit", "Remove" ], css_select("#scene_collection_#{castle.id} .scene-collection__actions .button").map { _1.text.strip }
      assert_select ".scene-collection__actions turbo-frame#new_scene_plan_#{castle.id} a[href=?]", new_campaign_scene_plan_path(@campaign, collection: castle.id)
      assert_select ".scene-collection__actions .button_to .button--danger", "Remove"
    end
    get new_campaign_scene_plan_path(@campaign, collection: castle.id)
    assert_select "turbo-frame#new_scene_plan_#{castle.id} select[name='scene_plan[scene_collection_id]'] option[selected][value=?]", castle.id.to_s, "The castle"

    post campaign_scene_plans_path(@campaign), params: { scene_plan: { title: "The gatehouse", scene_collection_id: castle.id, story_question: "Are they expected?" } }
    post campaign_scene_plans_path(@campaign), params: { scene_plan: { title: "A storm rolls in" } }
    gatehouse, storm = @campaign.scene_plans.ordered.to_a
    assert_equal [ castle, nil ], [ gatehouse.scene_collection, storm.scene_collection ]

    get campaign_scene_plans_path(@campaign)
    assert_select "#scene_collection_#{castle.id} .scene-plans__title", "The gatehouse"

    assert_equal %w[ Edit Move Remove ], css_select("##{dom_id(storm)} .scene-plans__actions > .button, ##{dom_id(storm)} .scene-plans__actions > .button_to .button, ##{dom_id(storm)} .scene-plans__actions summary").map { _1.text.strip }
    assert_select "##{dom_id(storm)} details.scene-plans__move" do
      assert_select "summary", "Move"
      assert_select "form[action=?] button", campaign_scene_plan_path(@campaign, storm), "The castle"
      assert_select "input[name='scene_plan[scene_collection_id]'][value=?]", castle.id.to_s
      assert_select "button", { text: "Standalone scenes", count: 0 }, "not where it already is"
    end

    # Moving a scene sends only its collection.
    patch campaign_scene_plan_path(@campaign, storm), params: { scene_plan: { scene_collection_id: castle.id } }
    assert_equal [ castle, "A storm rolls in" ], [ storm.reload.scene_collection, storm.title ]
    patch campaign_scene_plan_path(@campaign, storm), params: { scene_plan: { scene_collection_id: "" } }
    assert_nil storm.reload.scene_collection

    get new_campaign_play_session_path(@campaign)
    assert_select "input[name=scene_collection_id]", 0, "a session doesn't pick a collection"
    post campaign_play_sessions_path(@campaign), params: { character_ids: [ characters(:tibbs).id ] }
    session = @campaign.reload.current_session
    assert_equal [ [ castle, [ gatehouse ] ], [ nil, [ storm ] ] ], session.scene_choices

    get new_campaign_scene_path(@campaign)
    assert_select "select[name='play_session[scene_collection_id]']", 0
    assert_equal [ "The castle", "Standalone scenes", "A new scene" ], css_select(".fold__title").map { _1.text.strip }
    assert_select ".scene-picker__group[open] .fold__title", "Standalone scenes", "collections start closed"

    # Started as written: its title, notes and story question, which opens the story roll.
    post campaign_scenes_path(@campaign), params: { scene_plan_id: gatehouse.id, as_written: "1" }
    scene = @campaign.reload.current_scene
    assert_equal [ "The gatehouse", scene, "Are they expected?" ], [ scene.title, gatehouse.reload.scene, scene.story_question ]
    follow_redirect!
    assert_select "[data-controller=modal-opener][data-modal-opener-url-value=?]", new_campaign_story_roll_path(@campaign, question: "Are they expected?")
    assert_select ".scene-bar__notes", /The baron is away/

    assert_equal [ [ nil, [ storm ] ] ], session.scene_choices, "a collection with none left to play isn't offered"

    # The last scene came from the castle: it comes first, open, on the prep page and in the picker.
    tower = @campaign.scene_collections.create!(title: "The tower")
    @campaign.scene_plans.create!(title: "The stair", scene_collection: tower)
    @campaign.scene_plans.create!(title: "The keep", scene_collection: castle)
    get campaign_scene_plans_path(@campaign)
    assert_equal [ "scene_collection_#{castle.id}", "scene_collection_#{tower.id}" ], css_select(".scene-prep__grid > details.scene-collection").map { _1["id"] }
    assert_select "details#scene_collection_#{castle.id}.scene-collection--current[open] .scene-collection__tag", "In progress"
    assert_select ".scene-collection__tag", 1
    assert_select "details#scene_collection_#{tower.id}:not([open])"
    scene.end!(by: identities(:gwen))
    get new_campaign_scene_path(@campaign)
    assert_equal [ "The castle In progress", "The tower", "Standalone scenes", "A new scene" ], css_select(".fold__title").map { _1.text.squish }
    assert_equal [ "The castle In progress", "Standalone scenes" ], css_select(".scene-picker__group[open] .fold__title").map { _1.text.squish }

    delete campaign_scene_collection_path(@campaign, castle)
    assert_nil storm.reload.scene_collection_id
    assert_equal 4, @campaign.scene_plans.count, "removing a collection keeps its scenes"
  end

  test "only the GM preps scenes" do
    sign_in_as identities(:pip)
    get campaign_scene_plans_path(@campaign)
    assert_response :forbidden
  end
end
