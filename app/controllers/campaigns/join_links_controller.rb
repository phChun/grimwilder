# The GM turns the invite link off, so no one new can join with it, or back
# on (the same link). Making a new link is Campaigns::JoinCodesController.
class Campaigns::JoinLinksController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    Current.campaign.update!(join_link_enabled: true)
    redirect_to edit_campaign_path(Current.campaign, anchor: "settings"), notice: "The invite link is on again."
  end

  def destroy
    Current.campaign.update!(join_link_enabled: false)
    redirect_to edit_campaign_path(Current.campaign, anchor: "settings"), notice: "The invite link is off. No one new can join with it."
  end
end
