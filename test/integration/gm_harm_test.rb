require "test_helper"

# The GM can mark harm, marks and conditions on a player's sheet; nothing else
# on it. When they do, it's logged, and the owner's sheet refreshes.
class GmHarmTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "the GM sees the Harm card's controls, but not the rest of the sheet's" do
    sign_in_as identities(:gwen)
    get character_path(@tibbs)

    assert_select "#damage form[action=?] button[aria-pressed=false]", character_damage_path(@tibbs), text: /\ABloodied: \+1t to Brawn and Agility/
    assert_select ".stat-card form[action=?] button[aria-label=?]", character_damage_path(@tibbs), "Mark Agility", text: "Mark"
    assert_select "#conditions form[action=?]", character_conditions_path(@tibbs)
    assert_select "details.stat-roll", 0, "only the owner rolls"
    assert_select ".identity .tally", 0, "nor spends spark or thread"
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", Turbo::StreamsChannel.signed_stream_name(@tibbs)
  end

  test "the GM marks harm: it's logged, the sheet says so, and the owner's sheet refreshes" do
    sign_in_as identities(:gwen)

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts @tibbs, count: 1 do
        patch character_damage_path(@tibbs), params: { character: { bloodied: true, marked_wits: true } }
      end
    end
    assert_redirected_to character_path(@tibbs, anchor: "damage")
    assert @tibbs.reload.bloodied?
    assert @tibbs.marked_wits?

    note = @campaign.rolls.note.last
    assert_equal [ "Gwen", "marked Bloodied and Wits on Tibbs" ], [ note.name, note.question ]

    sign_out
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "#damage .harm__changed", /\AGM marked Bloodied and Wits · less than a minute ago\z/
    assert_select "#table_feed .feed-item--note", /Gwen\s+marked Bloodied and Wits on Tibbs/
  end

  test "the GM adds, rolls and clears conditions" do
    sign_in_as identities(:gwen)

    post character_conditions_path(@tibbs), params: { condition: "4d poisoned" }
    assert_equal [ "4d poisoned" ], @tibbs.reload.conditions.pluck("name")
    assert_equal "added 4d poisoned on Tibbs", @campaign.rolls.note.last.question

    assert_no_difference -> { @campaign.rolls.note.count }, "the roll logs itself" do
      post character_condition_roll_path(@tibbs, 0)
    end
    assert_equal "Gibbletibble \"Tibbs\": poisoned", @campaign.rolls.pool.last.name

    delete character_condition_path(@tibbs, 0)
    assert_empty @tibbs.reload.conditions
  end

  test "harm only: the GM can't touch spark, thread or anything else through it" do
    sign_in_as identities(:gwen)

    patch character_damage_path(@tibbs), params: { character: { rattled: true, spark: 0, name: "Renamed" } }
    @tibbs.reload
    assert @tibbs.rattled?
    assert_equal [ 1, "Gibbletibble \"Tibbs\"" ], [ @tibbs.spark, @tibbs.name ]

    patch character_path(@tibbs), params: { quick: 1, character: { spark: 0 } }
    assert_response :forbidden
  end

  test "another player can't, and an outsider can't even find the sheet" do
    @campaign.memberships.create!(identity: identities(:stranger), role: :player)
    sign_in_as identities(:stranger)

    patch character_damage_path(@tibbs), params: { character: { bloodied: true } }
    assert_response :forbidden
    post character_conditions_path(@tibbs), params: { condition: "cursed" }
    assert_response :forbidden
    assert_not @tibbs.reload.bloodied?

    @campaign.memberships.find_by(identity: identities(:stranger)).destroy!
    patch character_damage_path(@tibbs), params: { character: { bloodied: true } }
    assert_response :not_found
  end

  test "the owner's own changes aren't logged" do
    sign_in_as identities(:pip)

    assert_no_difference -> { @campaign.rolls.note.count } do
      patch character_damage_path(@tibbs), params: { character: { bloodied: true } }
    end
    assert @tibbs.reload.bloodied?
  end

  test "vex: the GM inflicts it with a response, the table sees it, and it passes" do
    tibbs = characters(:tibbs)
    sign_in_as identities(:gwen)
    post character_vex_path(tibbs), params: { vex: "flight", subject: "  the ogre " }
    assert_equal [ "flight", "the ogre" ], tibbs.reload.values_at(:vex, :vex_subject)
    assert_match "took vex (flight, the ogre) on Tibbs", campaigns(:bramblewood).rolls.note.last.question

    get character_path(tibbs)
    assert_select "#damage .vex-toggle[aria-pressed=true][data-tip^=?]", "Run from the subject", text: /\AFlight/
    assert_select "#damage .vex-toggle[aria-pressed=false]", 3
    assert_select "#damage .vex__does", /Run from the subject.*\(the ogre\)/
    get campaign_table_path(campaigns(:bramblewood))
    assert_select ".party-card__harm", /Vex: flight \(the ogre\)/

    delete character_vex_path(tibbs)
    assert_nil tibbs.reload.vex
    post character_vex_path(tibbs), params: { vex: "panic" }
    assert_nil tibbs.reload.vex, "only the book's four responses"
  end

  test "vex clears when the scene ends and at a rest" do
    tibbs = characters(:tibbs)
    session = PlaySession.start!(campaigns(:bramblewood), characters: [ tibbs ], by: identities(:gwen))
    scene = Scene.start!(session, title: "The mill", by: identities(:gwen))
    tibbs.reload.update!(vex: "freeze")
    scene.end!(by: identities(:gwen))
    assert_nil tibbs.reload.vex

    tibbs.update!(vex: "fight")
    tibbs.rest!(by: identities(:gwen))
    assert_nil tibbs.reload.vex
  end
end
