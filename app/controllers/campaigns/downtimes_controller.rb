# Downtime (pg. 31): everyone heals, including the conditions the GM leaves
# ticked, per-session talents reset, campaign pools roll, and the one the GM
# picks is depleted. With Expanded downtime (pg. 142) the GM picks each
# character's action instead, and only those who rest heal. GM only.
class Campaigns::DowntimesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def new
    @characters = Current.campaign.resting_characters
    @pools = Current.campaign.downtime_pools
  end

  def create
    Current.campaign.downtime!(by: Current.identity, clear: Array(params[:clear]), deplete: params[:deplete].presence, actions: downtime_actions)
    back_to_table(anchor: "roll-log", notice: Current.campaign.expanded_downtime? ? "Downtime: time passes." : "Downtime: everyone heals.")
  rescue ArgumentError => error
    redirect_to new_campaign_downtime_path(Current.campaign), alert: error.message
  end

  private
    # Expanded downtime: each resting character's picks, by id.
    def downtime_actions
      fields = [ :plan, :goal_id, :goal_name, :goal_size, :unwind, :venture, actions: [] ]
      ids = Current.campaign.resting_characters.map { _1.id.to_s }
      params.fetch(:actions, {}).permit(ids.to_h { [ _1, fields ] }).to_h
    end
end
