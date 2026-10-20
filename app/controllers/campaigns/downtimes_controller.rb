# Downtime (pg. 30): everyone heals, including the conditions the GM leaves
# ticked, per-session talents reset, and campaign pools roll. GM only.
class Campaigns::DowntimesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def new
    @characters = Current.campaign.resting_characters
    @pools = Current.campaign.downtime_pools
  end

  def create
    Current.campaign.downtime!(by: Current.identity, clear: Array(params[:clear]))
    back_to_table(anchor: "roll-log", notice: "Downtime: everyone heals.")
  end
end
