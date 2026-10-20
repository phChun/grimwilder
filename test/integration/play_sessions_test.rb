require "test_helper"

class PlaySessionsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "the GM starts and ends a session from the table" do
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".scene-bar__status", /Between sessions/
    assert_select ".scene-bar a[href=?]", new_campaign_play_session_path(@campaign), text: "Start session"

    get new_campaign_play_session_path(@campaign)
    assert_select "input[name='character_ids[]'][checked]", 2, "everyone seated, ticked"
    assert_select "#session_recap", 0, "no recap before session 1"

    post campaign_play_sessions_path(@campaign), params: { character_ids: [ @tibbs.id ] }
    session = @campaign.current_session
    assert_redirected_to campaign_table_path(@campaign)
    assert_equal [ @tibbs ], session.characters

    follow_redirect!
    assert_select ".scene-bar__status", /Session 1 · live/
    assert_select ".scene-bar__title", "Between scenes"
    assert_select "#table_feed .feed-item--marker", /Session 1 begins/

    get new_campaign_play_session_ending_path(@campaign, session)
    post campaign_play_session_ending_path(@campaign, session), params: { standout: "1", notes: "A good one." }
    assert_redirected_to campaign_table_path(@campaign)
    assert_not session.reload.open?
    assert_equal 2, @tibbs.reload.level
    assert_match "Gibbletibble \"Tibbs\" reached level 2", flash[:notice]

    follow_redirect!
    assert_select "#table_feed .feed-item--marker a[href=?]", new_character_talent_path(@tibbs), text: "choose a talent"
  end

  test "session 2 asks for a recap and shows what happened last time" do
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen)).end!(by: identities(:gwen), notes: "Burned the bridge.")
    sign_in_as identities(:gwen)

    get new_campaign_play_session_path(@campaign)
    assert_select "h1", "Start session 2"
    assert_select "#session_recap"
    assert_select ".session-form__prompts", /Burned the bridge\./

    post campaign_play_sessions_path(@campaign), params: { character_ids: [ @tibbs.id ], recap: "Previously: fire." }
    assert_equal "Previously: fire.", @campaign.current_session.recap
    assert_equal 1, @campaign.reload.suspense
  end

  test "the GM sees and changes suspense; it never goes below 0" do
    sign_in_as identities(:gwen)

    patch campaign_suspense_path(@campaign), params: { by: 1 }
    patch campaign_suspense_path(@campaign), params: { by: 1 }
    patch campaign_suspense_path(@campaign), params: { by: -1 }
    assert_equal 1, @campaign.reload.suspense

    3.times { patch campaign_suspense_path(@campaign), params: { by: -1 } }
    assert_equal 0, @campaign.reload.suspense

    get campaign_table_path(@campaign)
    assert_select ".suspense-panel [aria-label=?]", "0 suspense"
  end

  test "players see the status line but none of the GM's session controls" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select ".live-banner", /Session 1/
    assert_select ".scene-bar", 0
    assert_select ".suspense-panel", 0
    assert_select ".table-rail__head .suspense-meter", 1, "suspense, read-only"
    assert_select "form[action=?]", campaign_suspense_path(@campaign), 0

    get campaign_table_path(@campaign)
    assert_response :forbidden

    get new_campaign_play_session_path(@campaign)
    assert_response :forbidden
    post campaign_play_session_ending_path(@campaign, session)
    assert_response :forbidden
    patch campaign_suspense_path(@campaign), params: { by: 1 }
    assert_response :forbidden
    assert session.reload.open?
    assert_equal 0, @campaign.reload.suspense
  end

  test "outsiders get a 404" do
    sign_in_as identities(:stranger)

    get new_campaign_play_session_path(@campaign)
    assert_response :not_found
  end

  test "starting a second session at once is refused" do
    PlaySession.start!(@campaign, characters: [], by: identities(:gwen))
    sign_in_as identities(:gwen)

    post campaign_play_sessions_path(@campaign), params: { character_ids: [ @tibbs.id ] }
    assert_response :unprocessable_entity
    assert_select ".flash--alert", "Session 1 is still going."
  end
end
