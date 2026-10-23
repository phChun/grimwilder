require "test_helper"

# One active campaign per account (Membership#one_active_campaign), and the
# GM marking a campaign done (Campaign::Done): a read-only archive that frees
# everyone for another, which the GM can reopen.
class CampaignDoneTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "a GM at one campaign can't start another" do
    sign_in_as identities(:gwen)
    get campaigns_path
    assert_select "#campaign-new ~ p", /each account can be in one active campaign at a time\. Later, playing in as many as you like will be free, and running more than one will be part of a paid plan/
    assert_select "form[action=?]", campaigns_path, 0

    assert_no_difference -> { Campaign.count } do
      post campaigns_path, params: { campaign: { name: "Elsewhere" } }
    end
  end

  test "a player at one campaign can't join another" do
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:stranger))
    sign_in_as identities(:pip)
    get join_path(elsewhere.join_code)
    assert_select ".auth__panel", /You're at The Bramblewood Accord/
    assert_select ".auth__panel", /leave it or wait for its GM to mark it done/
    assert_select ".auth__panel form", 0

    assert_no_difference -> { elsewhere.memberships.count } do
      post join_path(elsewhere.join_code)
    end
    assert_match(/one active campaign at a time/, flash[:alert])
  end

  test "the GM marks it done: read-only for everyone, and everyone's free" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "#done button[disabled]", "Mark The Bramblewood Accord done"
    post campaign_done_path(@campaign)
    assert_match(/End the session/, flash[:alert])
    assert_not @campaign.reload.done?

    session.end!(by: identities(:gwen))
    post campaign_done_path(@campaign)
    assert_redirected_to campaign_path(@campaign)
    assert @campaign.reload.done?
    assert_equal "The Bramblewood Accord is done", @campaign.rolls.marker.last.name

    get campaign_table_path(@campaign)
    assert_redirected_to campaign_path(@campaign)
    get campaign_path(@campaign)
    assert_select ".campaign-hero .eyebrow", /Done/
    assert_select "a[href=?]", campaign_table_path(@campaign), 0
    assert_select "a[href=?]", edit_campaign_path(@campaign, anchor: "done"), "Reopen it"

    assert_no_difference -> { @campaign.rolls.count } do
      post campaign_notes_path(@campaign), params: { text: "One more thing" }
      post campaign_pool_roll_path(@campaign, pools(:lookouts))
    end
    assert_match(/is done/, flash[:alert])
    assert_raises(ArgumentError) { @tibbs.reload.roll!("wits", by: identities(:pip)) }

    post campaigns_path, params: { campaign: { name: "The Next One" } }
    assert_equal "The Next One", Campaign.last.name
  end

  test "a done campaign's sheets and rail are for reading" do
    @campaign.update!(done_at: Time.current)
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select ".stat-roll", 0
    assert_select ".claim-bar", /The Bramblewood Accord is done/
    assert_select ".table-rail .composer", 0
    assert_select ".table-rail__done"
    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { speak_as: "table_talk", body: "hello?" }
    end
  end

  test "a character moves on from a done campaign without touching its log" do
    @campaign.update!(done_at: Time.current)
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:stranger))
    elsewhere.memberships.create!(identity: identities(:pip))

    assert_no_difference -> { @campaign.rolls.count } do
      @tibbs.seat!(elsewhere, by: identities(:pip))
    end
    assert_equal elsewhere, @tibbs.reload.campaign
    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.seat!(@campaign, by: identities(:pip)) }
  end

  test "the GM reopens it, unless someone there is at another campaign now" do
    @campaign.update!(done_at: Time.current)
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:stranger))
    elsewhere.memberships.create!(identity: identities(:pip))

    sign_in_as identities(:gwen)
    delete campaign_done_path(@campaign)
    assert_equal "Pip is at Elsewhere now, so The Bramblewood Accord can't reopen.", flash[:alert].sub(identities(:pip).display_name, "Pip")
    assert @campaign.reload.done?

    elsewhere.memberships.find_by(identity: identities(:pip)).destroy!
    delete campaign_done_path(@campaign)
    assert_redirected_to campaign_path(@campaign)
    assert_not @campaign.reload.done?
    assert_equal "The Bramblewood Accord reopens", @campaign.rolls.marker.last.name
  end

  test "only the GM marks it done" do
    sign_in_as identities(:pip)
    post campaign_done_path(@campaign)
    assert_response :forbidden
    assert_not @campaign.reload.done?
  end
end
