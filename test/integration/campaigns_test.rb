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

  test "each campaign's card says what it's about, your part in it, and where it stands" do
    campaign = campaigns(:bramblewood)
    campaign.update!(pitch: "Toll-roads and a quietly failing accord.")
    gwen = identities(:gwen)
    PlaySession.start!(campaign, characters: [ characters(:tibbs) ], by: gwen).end!(by: gwen)

    sign_in_as identities(:pip)
    get campaigns_path
    assert_select ".campaign-list .campaign-card", /#{campaign.name}/ do
      assert_select ".campaign-card__role", "Playing Tibbs"
      assert_select ".campaign-card__pitch", "Toll-roads and a quietly failing accord."
      assert_equal [ "Last played #{campaign.play_sessions.first.started_at.strftime("%a, %b %-d")}", "1 session" ], css_select(".campaign-card__fact").first(2).map(&:text)
      assert_select ".campaign-card__fact", /\d+ characters? · \d+ players?/
    end

    PlaySession.start!(campaign, characters: [ characters(:tibbs) ], by: gwen)
    sign_out
    sign_in_as gwen
    get campaigns_path
    assert_select ".campaign-card__role", "You're the GM"
    assert_select ".campaign-card__fact--live", "Live now · Session 2"
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

  test "the GM turns the invite link off, and on again" do
    campaign = campaigns(:bramblewood)
    sign_in_as identities(:gwen)
    delete campaign_join_link_path(campaign)
    assert_redirected_to edit_campaign_path(campaign, anchor: "settings")
    assert_not campaign.reload.join_link_enabled?

    get edit_campaign_path(campaign)
    assert_select "#settings form[action=?] button", campaign_join_link_path(campaign), "Turn the link on"
    assert_select "#settings .copy-field", 0
    get campaign_path(campaign)
    assert_select ".campaign-actions button[data-clipboard-text-value]", 0
    sign_out

    sign_in_as identities(:stranger)
    get join_path(campaign.join_code)
    assert_response :not_found
    assert_no_difference -> { campaign.memberships.count } do
      post join_path(campaign.join_code)
    end
    assert_response :not_found
    sign_out

    sign_in_as identities(:gwen)
    post campaign_join_link_path(campaign)
    assert campaign.reload.join_link_enabled?
    sign_out
    sign_in_as identities(:stranger)
    assert_difference -> { campaign.memberships.count } do
      post join_path(campaign.join_code)
    end
  end

  test "players can't manage the campaign" do
    campaign = campaigns(:bramblewood)
    sign_in_as identities(:pip)

    patch campaign_join_code_path(campaign)
    assert_response :forbidden
    delete campaign_join_link_path(campaign)
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

  test "the GM blocks a player: removed, and the link won't let them back" do
    campaign = campaigns(:bramblewood)
    sign_in_as identities(:gwen)

    get edit_campaign_path(campaign)
    assert_select "form[action=?] button", campaign_blocks_path(campaign), "Block"

    assert_difference -> { campaign.memberships.count }, -1 do
      post campaign_blocks_path(campaign), params: { membership_id: memberships(:pip_player).id }
    end
    assert_redirected_to edit_campaign_path(campaign, anchor: "settings")
    assert campaign.blocked?(identities(:pip))

    follow_redirect!
    block = campaign.blocks.sole
    assert_select "form[action=?] button", campaign_block_path(campaign, block), "Unblock"

    sign_out
    sign_in_as identities(:pip)
    get join_path(campaign.join_code)
    assert_select "p", /blocked you/
    assert_no_difference -> { campaign.memberships.count } do
      post join_path(campaign.join_code)
    end
    get campaign_path(campaign)
    assert_response :not_found

    sign_out
    sign_in_as identities(:gwen)
    delete campaign_block_path(campaign, block)
    assert_not campaign.blocked?(identities(:pip))

    sign_out
    sign_in_as identities(:pip)
    assert_difference -> { campaign.memberships.count }, 1 do
      post join_path(campaign.join_code)
    end
  end

  test "only the GM blocks, and never a GM" do
    campaign = campaigns(:bramblewood)
    sign_in_as identities(:pip)
    post campaign_blocks_path(campaign), params: { membership_id: memberships(:gwen_gm).id }
    assert_response :forbidden

    sign_out
    sign_in_as identities(:gwen)
    post campaign_blocks_path(campaign), params: { membership_id: memberships(:gwen_gm).id }
    assert_response :not_found
    assert_not campaign.blocked?(identities(:gwen))
  end
end
