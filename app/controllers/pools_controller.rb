# /pools from the main nav: pools live in a campaign, so send people to the
# one they most recently joined or started.
class PoolsController < ApplicationController
  require_authentication

  def index
    if membership = Current.identity.memberships.includes(:campaign).order(created_at: :desc).first
      redirect_to campaign_pools_path(membership.campaign)
    else
      redirect_to campaigns_path, notice: "Pools live in a campaign. Start one, or join with a link from your GM."
    end
  end
end
