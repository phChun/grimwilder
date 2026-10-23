# The GM starts the campaign's play over (Campaign::Reset): sessions and the
# roll log go, chat stays.
class Campaigns::ResetsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    Current.campaign.reset!
    redirect_to edit_campaign_path(Current.campaign), notice: "#{Current.campaign.name} is reset: no sessions, and a clean log."
  end
end
