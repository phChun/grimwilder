require "test_helper"

class MembershipPresenceTest < ActiveSupport::TestCase
  setup do
    @membership = memberships(:pip_player)
  end

  test "away until a page checks in; active while in use, idle when not, away once quiet" do
    assert_equal "away", @membership.presence

    @membership.check_in!(active: true)
    assert_equal "active", @membership.presence

    travel 40.seconds
    @membership.check_in!(active: false)
    assert_equal "active", @membership.presence, "another tab was in use a moment ago"

    travel Membership::PRESENCE_WINDOW
    @membership.check_in!(active: false)
    assert_equal "idle", @membership.presence

    travel Membership::PRESENCE_WINDOW + 1.second
    assert_equal "away", @membership.presence
  end
end
