require "test_helper"

class CampaignsTest < ActionDispatch::IntegrationTest
  test "starting a campaign makes you its GM" do
    sign_in_as identities(:stranger)

    assert_difference -> { Campaign.count }, 1 do
      post campaigns_path, params: { campaign: { name: "Ashen Road" } }
    end
    campaign = Campaign.order(:id).last
    assert_redirected_to campaign_path(campaign)
    assert identities(:stranger).membership_in(campaign).gm?

    follow_redirect!
    assert_select "button[data-clipboard-text-value=?]", join_url(campaign.join_code), text: /Copy invite link/
    assert_select "a[href=?]", campaign_table_path(campaign), text: "Open the GM table"
  end

  test "non-members get a 404" do
    sign_in_as identities(:stranger)

    get campaign_path(campaigns(:bramblewood))
    assert_response :not_found
  end

  test "a player joins through the link after signing in" do
    campaign = campaigns(:bramblewood)

    get join_path(campaign.join_code)
    assert_response :success
    assert_select "a[href=?]", new_session_path

    sign_in_as identities(:stranger)
    assert_redirected_to join_path(campaign.join_code)

    assert_difference -> { campaign.memberships.count }, 1 do
      post join_path(campaign.join_code)
    end
    assert_redirected_to campaign_path(campaign)
    assert identities(:stranger).membership_in(campaign).player?
  end

  test "a reset join link stops working" do
    campaign = campaigns(:bramblewood)
    old_code = campaign.join_code
    sign_in_as identities(:gwen)

    patch campaign_join_code_path(campaign)
    assert_redirected_to campaign_path(campaign)

    get join_path(old_code)
    assert_response :not_found
  end

  test "players can't manage the campaign" do
    campaign = campaigns(:bramblewood)
    sign_in_as identities(:pip)

    patch campaign_join_code_path(campaign)
    assert_response :forbidden

    patch campaign_path(campaign), params: { campaign: { name: "Mine now" } }
    assert_response :forbidden

    delete campaign_membership_path(campaign, memberships(:gwen_gm))
    assert_response :forbidden
  end

  test "a player can leave" do
    campaign = campaigns(:bramblewood)

    sign_in_as identities(:pip)
    delete campaign_membership_path(campaign, memberships(:pip_player))
    assert_redirected_to campaigns_path
    assert_nil identities(:pip).membership_in(campaign)
  end

  test "the last GM can't leave" do
    campaign = campaigns(:bramblewood)
    sign_in_as identities(:gwen)

    delete campaign_membership_path(campaign, memberships(:gwen_gm))
    assert_redirected_to edit_campaign_path(campaign)
    assert memberships(:gwen_gm).reload
  end
end
