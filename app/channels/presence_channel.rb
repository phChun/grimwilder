# Who's at the table right now, for the halos on chat lines. Each open page
# of a campaign subscribes and checks in every Membership::PRESENCE_BEAT,
# saying whether it's in use; every check-in goes out to the table as that
# member's presence. Pages that stop hearing from someone for
# Membership::PRESENCE_WINDOW let their halo go (presence_controller.js), so
# nothing has to announce a page closing, and a second open tab still counts.
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    @membership = current_identity&.memberships&.find_by(campaign_id: params[:campaign_id])
    return reject unless @membership

    stream_for @membership.campaign
    transmit({ presences: @membership.campaign.memberships.to_h { [ _1.identity_id, _1.presence ] } })
  end

  def check_in(data)
    @membership.check_in!(active: data["active"] == true)
    self.class.broadcast_to @membership.campaign, { identity_id: @membership.identity_id, presence: @membership.presence }
  end
end
