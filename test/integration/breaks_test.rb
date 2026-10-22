require "test_helper"

class BreaksTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @tibbs.update!(bloodied: true, conditions: [ "4d poisoned", { name: "twisted ankle", lasts: "scene" } ])
  end

  test "the GM rests and takes downtime from the between-scenes fold-out" do
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".between-scenes form[action=?]", campaign_rest_path(@campaign)
    assert_select ".between-scenes a[href=?]", new_campaign_downtime_path(@campaign)

    post campaign_rest_path(@campaign)
    assert_redirected_to campaign_table_path(@campaign, anchor: "roll-log")
    assert_not @tibbs.reload.bloodied?
    follow_redirect!
    assert_select ".toasts .toast--notice[role=status] .toast__message", "Everyone rests."
    assert_select ".flash", 0, "news is a toast, not a banner"

    get new_campaign_downtime_path(@campaign)
    assert_select "input[name='clear[]'][checked]", 2

    post campaign_downtime_path(@campaign), params: { clear: [ "#{@tibbs.id}:1" ] }
    assert_equal [ "4d poisoned" ], @tibbs.reload.conditions.pluck("name")

    follow_redirect!
    assert_select "#table_feed .feed-item--marker", /Downtime/
  end

  test "players can't rest or take downtime" do
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select ".between-scenes", 0

    post campaign_rest_path(@campaign)
    assert_response :forbidden
    get new_campaign_downtime_path(@campaign)
    assert_response :forbidden
    post campaign_downtime_path(@campaign)
    assert_response :forbidden
    assert @tibbs.reload.bloodied?
  end
end
