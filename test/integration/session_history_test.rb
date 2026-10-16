require "test_helper"

class SessionHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @before = @tibbs.roll!("wits", by: identities(:pip))

    first = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    @scene = Scene.start!(first, title: "The bridge at Mirefall", by: identities(:gwen),
      opening: { question: "Guarded?", odds: 2, thorns: 0, character: nil, spend_spark: 0 })
    @in_scene = @tibbs.roll!("agility", by: identities(:pip))
    @scene.end!(by: identities(:gwen), notes: "Across, barely.")
    @hidden = pools(:ambush).roll!(by: identities(:gwen))
    first.end!(by: identities(:gwen), standout: true, notes: "Next: the Mire.")
    @first = first
  end

  test "members see the history: sessions, XP, level-ups, and what came before" do
    sign_in_as identities(:pip)

    get campaign_play_sessions_path(@campaign)
    assert_select ".session-card__title a[href=?]", campaign_play_session_path(@campaign, @first), text: "Session 1"
    assert_select ".session-card__meta", /1 scene · 1 character there · \+2 XP \(standout\) · Gibbletibble "Tibbs" reached level 2/
    assert_select ".session-before ##{dom_id(@before)}"
  end

  test "a session page shows scenes with their bookends and rolls, oldest first; GM-only rolls stay hidden" do
    sign_in_as identities(:pip)

    get campaign_play_session_path(@campaign, @first)
    assert_select "##{dom_id(@scene)} .panel__title", "Scene 1: The bridge at Mirefall"
    assert_select "##{dom_id(@scene)} .session-scene__bookend", /Opened with a story roll/
    assert_select "##{dom_id(@scene)}", /Across, barely\./
    assert_select "##{dom_id(@scene)} .roll-log > li:nth-child(1)", /The bridge at Mirefall/, "the scene's opening marker first"
    assert_select "##{dom_id(@scene)} ##{dom_id(@in_scene)}"
    assert_select "##{dom_id(@hidden)}", 0
    assert_select "a[href=?]", character_path(@tibbs), text: @tibbs.name
    assert_select ".session-page__edit", 0, "players can't edit"
  end

  test "the GM edits the recap, notes and a scene afterwards" do
    sign_in_as identities(:gwen)

    get campaign_play_session_path(@campaign, @first)
    assert_select "##{dom_id(@hidden)}"

    patch campaign_play_session_path(@campaign, @first), params: { play_session: { notes: "Next: the Mire, for sure." } }
    assert_equal "Next: the Mire, for sure.", @first.reload.notes
    patch campaign_scene_path(@campaign, @scene), params: { scene: { notes: "Across. Barely." } }
    assert_equal "Across. Barely.", @scene.reload.notes
  end

  test "players can't edit sessions or scenes" do
    sign_in_as identities(:pip)

    patch campaign_play_session_path(@campaign, @first), params: { play_session: { notes: "Mine now" } }
    assert_response :forbidden
    patch campaign_scene_path(@campaign, @scene), params: { scene: { notes: "Mine now" } }
    assert_response :forbidden
  end

  test "players are prompted for a best moment until they've shared one" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs, characters(:bram) ], by: identities(:gwen))
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select "#moment-prompt input[name=character_id][value=?]", @tibbs.id.to_s

    post campaign_play_session_moments_path(@campaign, session), params: { character_id: characters(:bram).id, text: "Not mine" }
    assert_response :forbidden

    post campaign_play_session_moments_path(@campaign, session), params: { character_id: @tibbs.id, text: "Talked the troll down." }
    assert_redirected_to campaign_path(@campaign)

    follow_redirect!
    assert_select "#moment-prompt", 0

    get campaign_play_session_path(@campaign, session)
    assert_select "#moments", /Talked the troll down\./
  end

  test "the next session's form shows last session's scenes and moments as prompts" do
    sign_in_as identities(:gwen)

    get new_campaign_play_session_path(@campaign)
    assert_select "h1", "Start session 2"
    assert_select ".session-form__scenes", /The bridge at Mirefall: Across, barely\./

    second = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    second.moments.create!(character: @tibbs, identity: identities(:pip), text: "Talked the troll down.")
    second.end!(by: identities(:gwen))

    get new_campaign_play_session_path(@campaign)
    assert_select "h1", "Start session 3"
    assert_select ".session-form__prompts", /Talked the troll down\./
  end

  test "the status line links to the history" do
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select ".session-bar__status", /Between sessions/
    assert_select ".session-bar__status a[href=?]", campaign_play_sessions_path(@campaign), text: "History"
  end
end
