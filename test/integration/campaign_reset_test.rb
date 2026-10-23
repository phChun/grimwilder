require "test_helper"

# The GM resets a campaign (Campaign::Reset): sessions and the roll log go,
# the chat stays.
class CampaignResetTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "the GM clears sessions, scenes and the roll log, and the chat stays" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    Scene.start!(session, title: "The mill fire", by: identities(:gwen))
    @tibbs.roll!("wits", by: identities(:pip))
    Roll.note!(campaign: @campaign, by: identities(:gwen), text: "The bell tolls")
    @campaign.messages.create!(identity: identities(:pip), name: "Pip", kind: "table_talk", body: "brb")
    chat = @campaign.messages.count

    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "form[action=?] button.button--danger", campaign_reset_path(@campaign), "Reset The Bramblewood Accord"

    post campaign_reset_path(@campaign)
    assert_redirected_to edit_campaign_path(@campaign)
    assert_equal 0, @campaign.play_sessions.count
    assert_equal 0, @campaign.scenes.count
    assert_equal 0, @campaign.rolls.count
    assert_equal chat, @campaign.messages.count
    assert_nil @campaign.current_session

    assert_equal 1, PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen)).number, "play starts again at Session 1"
  end

  test "only the GM resets" do
    @tibbs.roll!("wits", by: identities(:pip))
    sign_in_as identities(:pip)
    post campaign_reset_path(@campaign)
    assert_response :forbidden
    assert_equal 1, @campaign.rolls.count
  end
end
