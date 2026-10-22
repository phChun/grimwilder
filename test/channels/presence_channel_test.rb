require "test_helper"

class PresenceChannelTest < ActionCable::Channel::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @pip = memberships(:pip_player)
  end

  test "members subscribe, get everyone's presence, and check in for the table" do
    @campaign.memberships.find_by(identity: identities(:gwen)).check_in!(active: false)
    stub_connection current_identity: identities(:pip)
    subscribe campaign_id: @campaign.id

    assert subscription.confirmed?
    assert_has_stream_for @campaign
    assert_equal({ identities(:gwen).id => "idle", identities(:pip).id => "away" }, transmissions.last["presences"].transform_keys(&:to_i))

    assert_broadcast_on(PresenceChannel.broadcasting_for(@campaign), identity_id: identities(:pip).id, presence: "active") do
      perform :check_in, active: true
    end
    assert_equal "active", @pip.reload.presence
  end

  test "an idle page keeps you seen, not active" do
    stub_connection current_identity: identities(:pip)
    subscribe campaign_id: @campaign.id

    assert_broadcast_on(PresenceChannel.broadcasting_for(@campaign), identity_id: identities(:pip).id, presence: "idle") do
      perform :check_in, active: false
    end
  end

  test "outsiders and signed-out connections are turned away" do
    stub_connection current_identity: identities(:stranger)
    subscribe campaign_id: @campaign.id
    assert subscription.rejected?

    stub_connection current_identity: nil
    subscribe campaign_id: @campaign.id
    assert subscription.rejected?
  end
end
