# The GM blocks a player (removing them and keeping the invite link from
# letting them back in) or lifts a block, from settings.
class Campaigns::BlocksController < ApplicationController
  include CampaignScoped

  skip_before_action :refuse_when_archived # like removing someone, fine once archived
  before_action :require_gm

  def create
    membership = Current.campaign.memberships.player.find(params.expect(:membership_id))
    Current.campaign.block!(membership, by: Current.identity)
    redirect_to edit_campaign_path(Current.campaign, anchor: "settings"), notice: "#{membership.identity.display_name} was removed and blocked."
  end

  def destroy
    block = Current.campaign.blocks.find(params[:id])
    block.destroy!
    redirect_to edit_campaign_path(Current.campaign, anchor: "settings"), notice: "#{block.identity.display_name} can join again with the invite link."
  end
end
