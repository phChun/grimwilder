# A GM removes someone from the campaign, or a player leaves it.
class Campaigns::MembershipsController < ApplicationController
  include CampaignScoped

  def destroy
    membership = Current.campaign.memberships.find(params[:id])
    leaving = membership == Current.membership

    unless leaving || gm?
      return head :forbidden
    end

    if membership.destroy
      if leaving
        redirect_to campaigns_path, notice: "You left #{Current.campaign.name}."
      else
        redirect_to Current.campaign, notice: "#{membership.identity.display_name} was removed."
      end
    else
      redirect_to Current.campaign, alert: membership.errors.full_messages.to_sentence
    end
  end
end
