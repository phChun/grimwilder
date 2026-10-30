# Downtime (pg. 31): everyone heals, including the conditions the GM leaves
# ticked, per-session talents reset, campaign pools roll, and the one the GM
# picks is depleted. GM only.
class Campaigns::DowntimesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def new
    @characters = Current.campaign.resting_characters
    @pools = Current.campaign.downtime_pools
  end

  def create
    Current.campaign.downtime!(by: Current.identity, clear: Array(params[:clear]), deplete: params[:deplete].presence)
    back_to_table(anchor: "roll-log", notice: "Downtime: everyone heals.")
  end
end
