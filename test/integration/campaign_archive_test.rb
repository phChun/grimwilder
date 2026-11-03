require "test_helper"

# Plans (Identity::Plans: Free runs one active campaign and plays in any
# number), and the GM archiving a campaign (Campaign::Archive): read-only, an
# archive that frees room for another, which the GM can unarchive.
class CampaignArchiveTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "a GM at one campaign can't start another" do
    sign_in_as identities(:gwen)
    get campaigns_path
    assert_select "#campaign-new p", /You run The Bramblewood Accord\. On the Free plan, you can run 1 active campaign at a time, and play in as many as you like\. To start another, archive one/
    assert_select "form[action=?]", campaigns_path, 0
    assert_select ".tool-grid__list > li:last-child #campaign-new h2", "Create new campaign"

    assert_no_difference -> { Campaign.count } do
      post campaigns_path, params: { campaign: { name: "Elsewhere" } }
    end
  end

  test "a GM on the tester plan starts as many as they like" do
    identities(:gwen).update!(plan: "tester")
    sign_in_as identities(:gwen)
    get campaigns_path
    assert_select "form[action=?]", campaigns_path

    assert_difference -> { Campaign.count } do
      post campaigns_path, params: { campaign: { name: "Elsewhere" } }
    end
  end

  test "a player on the free plan joins another campaign" do
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:stranger))
    sign_in_as identities(:pip)
    get join_path(elsewhere.join_code)
    assert_select ".auth__panel form[action=?]", join_path(elsewhere.join_code)

    assert_difference -> { elsewhere.memberships.count } do
      post join_path(elsewhere.join_code)
    end
    assert_redirected_to campaign_path(elsewhere)
  end

  test "the GM archives it: read-only for everyone, and everyone's free" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "#archive button[disabled]", "Archive The Bramblewood Accord"
    post campaign_archive_path(@campaign)
    assert_match(/End the session/, flash[:alert])
    assert_not @campaign.reload.archived?

    session.end!(by: identities(:gwen))
    post campaign_archive_path(@campaign)
    assert_redirected_to campaign_path(@campaign)
    assert @campaign.reload.archived?
    assert_equal "The Bramblewood Accord is archived", @campaign.rolls.marker.last.name

    get campaign_table_path(@campaign)
    assert_redirected_to campaign_path(@campaign)
    get campaign_path(@campaign)
    assert_select ".campaign-hero .eyebrow", /Archived/
    assert_select "a[href=?]", campaign_table_path(@campaign), 0
    assert_select "a[href=?]", edit_campaign_path(@campaign, anchor: "archive"), "Unarchive it"

    assert_no_difference -> { @campaign.rolls.count } do
      post campaign_pool_roll_path(@campaign, pools(:lookouts))
    end
    assert_match(/is archived/, flash[:alert])
    assert_raises(ArgumentError) { @tibbs.reload.roll!("wits", by: identities(:pip)) }

    post campaigns_path, params: { campaign: { name: "The Next One" } }
    assert_equal "The Next One", Campaign.last.name
  end

  test "an archived campaign's sheets and rail are for reading" do
    @campaign.update!(archived_at: Time.current)
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select ".stat-roll", 0
    assert_select ".claim-bar", /The Bramblewood Accord is archived/
    assert_select ".table-rail .composer", 0
    assert_select ".table-rail__archived"
    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { context: "talk", body: "hello?" }
    end
  end

  test "a character moves on from an archived campaign without touching its log" do
    @campaign.update!(archived_at: Time.current)
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:stranger))
    elsewhere.memberships.create!(identity: identities(:pip))

    assert_no_difference -> { @campaign.rolls.count } do
      @tibbs.seat!(elsewhere, by: identities(:pip))
    end
    assert_equal elsewhere, @tibbs.reload.campaign
    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.seat!(@campaign, by: identities(:pip)) }
  end

  test "the GM unarchives it, unless that puts someone there past their plan" do
    @campaign.update!(archived_at: Time.current)
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:gwen))
    elsewhere.memberships.create!(identity: identities(:pip))

    sign_in_as identities(:gwen)
    delete campaign_archive_path(@campaign)
    assert_equal "Gwen runs as many active campaigns as the Free plan allows, so The Bramblewood Accord can't come back from the archive.", flash[:alert]
    assert @campaign.reload.archived?

    identities(:gwen).update!(plan: "tester")
    delete campaign_archive_path(@campaign)
    assert_redirected_to campaign_path(@campaign)
    assert_not @campaign.reload.archived?
    assert_equal "The Bramblewood Accord is back from the archive", @campaign.rolls.marker.last.name
  end

  test "only the GM archives it" do
    sign_in_as identities(:pip)
    post campaign_archive_path(@campaign)
    assert_response :forbidden
    assert_not @campaign.reload.archived?
  end

  test "an archived campaign's sheets refuse play: harm, conditions, talent uses, pushes and claims" do
    @campaign.update!(archived_at: Time.current)
    sign_in_as identities(:pip)

    patch character_damage_path(@tibbs), params: { character: { bloodied: true } }
    assert_match(/is archived/, flash[:alert])
    assert_not @tibbs.reload.bloodied?

    assert_no_changes -> { @tibbs.reload.conditions } do
      post character_conditions_path(@tibbs), params: { condition: "poisoned" }
    end
    @tibbs.update!(level: 2, talent_keys: %w[ mastermind lurker ])
    assert_no_changes -> { @tibbs.reload.marked_wits } do
      post character_talent_push_path(@tibbs, "lurker"), params: { stat: "wits" }
    end
    assert_raises(ArgumentError) { @tibbs.reload.push!("wits", talent_key: "lurker", by: identities(:pip)) }
    assert_not @tibbs.releasable_by?(identities(:pip)), "can't give them back to an archived table"
  end

  test "the GM archives and unarchives from the campaigns list" do
    sign_in_as identities(:gwen)
    get campaigns_path
    assert_select "##{dom_id(@campaign, :more)} form[action=?][data-turbo-confirm*=?] button", campaign_archive_path(@campaign), "nothing new is played there", "Archive"

    post campaign_archive_path(@campaign), params: { return_to: "campaigns" }
    assert_redirected_to campaigns_path
    assert @campaign.reload.archived?
    follow_redirect!
    assert_select "##{dom_id(@campaign, :more)}", 0, "out of the grid"
    assert_select ".archive-list ##{dom_id(@campaign, :archived)} .archive-list__meta", /archived/
    assert_select "##{dom_id(@campaign, :archived)} form[action=?] button", campaign_archive_path(@campaign), "Unarchive"

    delete campaign_archive_path(@campaign), params: { return_to: "campaigns" }
    assert_redirected_to campaigns_path
    assert_not @campaign.reload.archived?
  end

  test "the list's Archive waits for the session to end, and an unarchive with no room says why" do
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    sign_in_as identities(:gwen)
    get campaigns_path
    assert_select "##{dom_id(@campaign, :more)} button[disabled]", "Archive"
    assert_select "##{dom_id(@campaign, :more)} .field__hint", "End the session first."

    @campaign.current_session.end!(by: identities(:gwen))
    @campaign.archive!(by: identities(:gwen))
    Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:gwen))
    delete campaign_archive_path(@campaign), params: { return_to: "campaigns" }
    assert_redirected_to campaigns_path
    assert_match(/can't come back from the archive/, flash[:alert])
    assert @campaign.reload.archived?
  end

  test "players' cards have no menu" do
    sign_in_as identities(:pip)
    get campaigns_path
    assert_select "##{dom_id(@campaign, :more)}", 0
  end
end
