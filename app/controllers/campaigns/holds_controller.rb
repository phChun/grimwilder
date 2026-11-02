# "Play this one" on the campaigns list: a GM whose plan has this campaign on
# hold plays it instead of their least recently played one
# (Identity::Plans#keep_playing!).
class Campaigns::HoldsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def destroy
    Current.identity.keep_playing!(Current.membership)
    redirect_to campaigns_path, notice: "#{Current.campaign.name} is back on."
  rescue ArgumentError => error
    redirect_to campaigns_path, alert: error.message
  end
end
