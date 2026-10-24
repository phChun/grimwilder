require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "email addresses are normalized and unique" do
    identity = Identity.create!(email_address: "  New@Example.COM ")
    assert_equal "new@example.com", identity.email_address

    assert_no_difference -> { Identity.count } do
      assert_equal identity, Identity.find_or_create_for_sign_in!("NEW@example.com")
    end
  end

  test "display name falls back to the email's local part" do
    assert_equal "someone", Identity.new(email_address: "someone@example.com").display_name
    assert_not Identity.new(email_address: "someone@example.com").profile_complete?
  end
end

class IdentityPlansTest < ActiveSupport::TestCase
  test "new accounts are on the free plan, and only known plans are allowed" do
    identity = Identity.create!(email_address: "new@example.com")
    assert_equal "free", identity.plan
    assert_equal "Free", identity.current_plan.name
    assert_not identity.update(plan: "gold")
  end

  test "free runs one active campaign; done ones don't count" do
    gwen = identities(:gwen)
    assert_not gwen.room_to_run?
    assert gwen.room_to_play?
    error = assert_raises(ActiveRecord::RecordInvalid) { Campaign.create_with_gm!(name: "Elsewhere", gm: gwen) }
    assert_match "You run The Bramblewood Accord. On the Free plan, you can run 1 active campaign at a time, and play in as many as you like.", error.message

    campaigns(:bramblewood).update!(done_at: Time.current)
    assert gwen.room_to_run?
    assert Campaign.create_with_gm!(name: "Elsewhere", gm: gwen)
  end

  test "free plays in as many as they like, and a tester runs as many as they like" do
    pip = identities(:pip)
    2.times { |n| Campaign.create_with_gm!(name: "Table #{n}", gm: identities(:tess)).memberships.create!(identity: pip) }
    assert_equal 3, pip.active_memberships(role: :player).count
    assert_equal 2, identities(:tess).active_memberships(role: :gm).count
  end

  test "a plan with a playing limit refuses another seat, and says why" do
    pip = identities(:pip)
    pip.define_singleton_method(:current_plan) { Plan.new(key: "tiny", name: "Tiny", running: 1, playing: 1) }
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:tess))

    membership = elsewhere.memberships.build(identity: pip)
    assert_not membership.valid?
    assert_equal [ "You play in The Bramblewood Accord. On the Tiny plan, you can play in 1 active campaign at a time. To join another, leave one or wait for its GM to mark it done." ],
      membership.errors.full_messages
  end

  test "an account moved to a smaller plan keeps its campaigns and shows as over" do
    tess = identities(:tess)
    2.times { |n| Campaign.create_with_gm!(name: "Table #{n}", gm: tess) }
    assert_empty tess.over_plan

    tess.update!(plan: "free")
    assert_equal({ "gm" => 2 }, tess.over_plan)
    assert_equal 2, tess.active_memberships(role: :gm).count
    assert_not tess.room_to_run?
  end
end
