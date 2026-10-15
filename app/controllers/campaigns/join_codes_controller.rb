# The GM resets the join link, so old links stop working.
class Campaigns::JoinCodesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def update
    Current.campaign.reset_join_code!
    redirect_to Current.campaign, notice: "New join link created. The old one no longer works."
  end
end
