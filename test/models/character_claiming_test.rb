require "test_helper"

class CharacterClaimingTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "a GM who leaves passes their up-for-grabs characters to another GM" do
    @campaign.memberships.create!(identity: identities(:stranger), role: "gm")
    @tibbs.release!(by: identities(:gwen))

    memberships(:gwen_gm).destroy!
    @tibbs.reload
    assert @tibbs.owned_by?(identities(:stranger))
    assert @tibbs.up_for_grabs?
    assert_equal @campaign, @tibbs.campaign
    assert_nil characters(:bram).reload.campaign, "the GM's own character leaves with them"
  end

  test "deleting the campaign leaves up-for-grabs characters with their GM, no longer offered" do
    @tibbs.release!(by: identities(:gwen))
    @campaign.destroy!

    @tibbs.reload
    assert_nil @tibbs.campaign
    assert_not @tibbs.up_for_grabs?
    assert @tibbs.owned_by?(identities(:gwen))
  end

  test "picking needs a seat at the table, and only one person gets it" do
    @tibbs.release!(by: identities(:gwen))
    assert_not @tibbs.claimable_by?(identities(:stranger))

    @tibbs.claim!(by: identities(:pip))
    assert_raises(ArgumentError) { @tibbs.claim!(by: identities(:gwen)) }
    assert @tibbs.reload.owned_by?(identities(:pip))
  end
end
