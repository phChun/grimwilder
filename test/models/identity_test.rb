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

  test "free runs one active campaign; archived ones don't count" do
    gwen = identities(:gwen)
    assert_not gwen.room_to_run?
    assert gwen.room_to_play?
    error = assert_raises(ActiveRecord::RecordInvalid) { Campaign.create_with_gm!(name: "Elsewhere", gm: gwen) }
    assert_match "You run The Bramblewood Accord. On the Free plan, you can run 1 active campaign at a time, and play in as many as you like.", error.message

    campaigns(:bramblewood).update!(archived_at: Time.current)
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
    assert_equal [ "You play in The Bramblewood Accord. On the Tiny plan, you can play in 1 active campaign at a time. To join another, leave one or wait for its GM to archive it." ],
      membership.errors.full_messages
  end

  test "a smaller plan holds all but the most recently played, by last session" do
    tess = identities(:tess)
    tess.update!(plan: "tester")
    old, recent, fresh = 3.times.map { |n| Campaign.create_with_gm!(name: "Table #{n}", gm: tess) }
    travel_to(10.days.ago) { PlaySession.start!(old, characters: [], by: tess).end!(by: tess) }
    travel_to(1.day.ago) { PlaySession.start!(recent, characters: [], by: tess).end!(by: tess) }
    fresh.update_columns(created_at: 20.days.ago)

    tess.apply_plan!("free")
    assert_equal "free", tess.reload.plan
    assert_equal [ recent ], tess.active_memberships(role: :gm).map(&:campaign)
    assert_equal [ old, fresh ].sort, tess.held_memberships.map(&:campaign).sort
    assert old.reload.on_hold?
    assert_not recent.reload.on_hold?
    assert_equal "Table 0 is on hold: its GM's plan runs fewer campaigns", old.rolls.marker.last.name
    assert_nil recent.rolls.marker.where("name LIKE ?", "%on hold%").first
    assert_not tess.room_to_run?
  end

  test "a bigger plan lifts every hold" do
    tess = identities(:tess)
    tess.update!(plan: "tester")
    held = 2.times.map { |n| Campaign.create_with_gm!(name: "Table #{n}", gm: tess) }
    tess.apply_plan!("free")
    assert_equal 1, tess.held_memberships.count

    tess.apply_plan!("patron")
    assert_empty tess.held_memberships
    assert held.none? { _1.reload.on_hold? }
    assert_equal 1, held.count { _1.rolls.marker.exists?(name: "#{_1.name} is back on") }
  end

  test "a held GM doesn't put a campaign on hold while a co-GM has room, and archived campaigns are left alone" do
    tess = identities(:tess)
    tess.update!(plan: "tester")
    shared = Campaign.create_with_gm!(name: "Shared", gm: tess)
    shared.update_columns(created_at: 1.year.ago)
    archived = Campaign.create_with_gm!(name: "Old", gm: tess)
    archived.archive!(by: tess)
    Campaign.create_with_gm!(name: "Mine", gm: tess)
    co_gm = Identity.create!(email_address: "co@example.com", name: "Cora")
    shared.memberships.create!(identity: co_gm, role: "gm")

    tess.apply_plan!("free")
    assert tess.membership_in(shared).held?
    assert_not shared.reload.on_hold?, "Cora still runs it"
    assert_not tess.membership_in(archived).held?

    co_gm.apply_plan!("free")
    assert_not co_gm.membership_in(shared).held?, "it's the only one Cora runs"
  end

  test "keep_playing! swaps a held campaign for the least recently played, unless that one's in session" do
    tess = identities(:tess)
    tess.update!(plan: "tester")
    first, second = 2.times.map { |n| Campaign.create_with_gm!(name: "Table #{n}", gm: tess) }
    first.update_columns(created_at: 1.week.ago)
    tess.apply_plan!("free")
    held = tess.membership_in(first)
    assert held.held?

    session = PlaySession.start!(second, characters: [], by: tess)
    error = assert_raises(ArgumentError) { tess.keep_playing!(held) }
    assert_equal "End the session at Table 1 first.", error.message
    session.end!(by: tess)

    tess.keep_playing!(held.reload)
    assert_not first.reload.on_hold?
    assert second.reload.on_hold?
    assert_equal "Table 0 is back on", first.rolls.marker.last.name
    assert_equal "Table 1 is on hold: its GM's plan runs fewer campaigns", second.rolls.marker.last.name
  end

  test "archiving the one being played leaves room to play a held one without holding another" do
    tess = identities(:tess)
    tess.update!(plan: "tester")
    first, second = 2.times.map { |n| Campaign.create_with_gm!(name: "Table #{n}", gm: tess) }
    tess.apply_plan!("free")
    held, playing = [ first, second ].map { tess.membership_in(_1) }.partition(&:held?).map(&:sole)
    playing.campaign.archive!(by: tess)
    assert_nil tess.next_to_hold

    tess.keep_playing!(held.reload)
    assert_empty tess.held_memberships
  end
end
