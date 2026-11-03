require "test_helper"

class ScenesTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "with no session going, starting a scene offers to start one" do
    sign_in_as identities(:gwen)

    get new_campaign_scene_path(@campaign)
    assert_select "a[href=?]", new_campaign_play_session_path(@campaign), text: "Start a session first"
  end

  test "the GM runs a scene: open with a story roll, roll a montage, close it" do
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    @tibbs.update!(conditions: [ { name: "twisted ankle", lasts: "scene" } ])
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".scene-bar a[href=?]", new_campaign_scene_path(@campaign), text: "Start scene"

    post campaign_scenes_path(@campaign), params: { title: "The bridge at Mirefall", open_with_story: "1", question: "Is it guarded?", odds: 2 }
    scene = @campaign.current_scene
    assert_redirected_to campaign_table_path(@campaign, anchor: "roll-log")
    assert scene.opening_roll.story?

    follow_redirect!
    assert_select ".scene-bar__status", /Session 1 · live · Scene 1 of 1/
    assert_select ".scene-clock [data-controller=clock][role=timer]", 2
    assert_select ".scene-clock__item", text: /Session\s*\d+:\d\d/
    assert_select ".scene-clock__item", text: /Scene\s*\d+:\d\d/
    assert_select ".scene-bar__title", "The bridge at Mirefall"
    assert_select ".scene-bar a[href=?]", new_campaign_scene_ending_path(@campaign, scene, then: "new_scene"), text: "Cut to new scene"

    get new_campaign_scene_ending_path(@campaign, scene)
    assert_select "a[href=?]", new_campaign_montage_path(@campaign, then: "end_scene", scene: scene.title)
    assert_select "input[name='clear[]'][value=?][checked]", "#{@tibbs.id}:0"

    post campaign_montages_path(@campaign), params: { then: "end_scene", scene: "Across", participants: { @tibbs.id => { in: "1" } } }
    assert_redirected_to new_campaign_scene_ending_path(@campaign, scene)
    follow_redirect!
    assert_select "turbo-cable-stream-source[signed-stream-name]", minimum: 1
    assert_select "#roll_call_campaign_#{@campaign.id} .roll-call__seat", 1, "the GM sees the montage waiting on Tibbs"

    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: @campaign.roll_calls.last.id, character_id: @tibbs.id }
    montage = scene.rolls.montage.last
    assert montage, "the GM rolled for Tibbs, so the montage landed"

    get new_campaign_scene_ending_path(@campaign, scene)
    assert_select "select[name=closing_roll_id] option[selected][value=?]", montage.id.to_s

    post campaign_scene_ending_path(@campaign, scene), params: { closing_roll_id: montage.id, notes: "Across.", clear: [ "#{@tibbs.id}:0" ] }
    assert_equal montage, scene.reload.closing_roll
    assert_empty @tibbs.reload.conditions
  end

  test "ending a session with a scene open asks about scene conditions" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    Scene.start!(session, title: "The bridge", by: identities(:gwen))
    @tibbs.update!(conditions: [ { name: "twisted ankle", lasts: "scene" } ])
    sign_in_as identities(:gwen)

    get new_campaign_play_session_ending_path(@campaign, session)
    assert_select "input[name='clear[]'][checked]", 1

    post campaign_play_session_ending_path(@campaign, session), params: { clear: [] }
    assert_equal [ "twisted ankle" ], @tibbs.reload.conditions.pluck("name"), "left unticked, it lingers"
    assert_nil @campaign.current_scene
  end

  test "players can't start or end scenes" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    scene = Scene.start!(session, title: "The bridge", by: identities(:gwen))
    sign_in_as identities(:pip)

    get new_campaign_scene_path(@campaign)
    assert_response :forbidden
    post campaign_scene_ending_path(@campaign, scene)
    assert_response :forbidden
    assert scene.reload.open?
  end
end
