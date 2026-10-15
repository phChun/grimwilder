require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  test "create_with_gm makes the creator its GM" do
    campaign = Campaign.create_with_gm!(name: "  Ashen   Road ", gm: identities(:stranger))

    assert_equal "Ashen Road", campaign.name
    assert campaign.memberships.find_by(identity: identities(:stranger)).gm?
    assert_match(/\A\w{4}-\w{4}-\w{4}\z/, campaign.join_code)
  end

  test "reset_join_code replaces the code" do
    campaign = campaigns(:bramblewood)

    assert_changes -> { campaign.reload.join_code } do
      campaign.reset_join_code!
    end
  end

  test "the last GM can't be removed" do
    assert_not memberships(:gwen_gm).destroy
    assert memberships(:pip_player).destroy
  end

  test "deleting a campaign removes its memberships" do
    assert_difference -> { Membership.count }, -2 do
      campaigns(:bramblewood).destroy
    end
  end
end
