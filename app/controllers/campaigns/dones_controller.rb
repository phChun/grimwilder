# The GM marks the campaign done (Campaign::Done), making it a read-only
# archive that no longer counts as anyone's active campaign, or reopens it.
class Campaigns::DonesController < ApplicationController
  include CampaignScoped

  skip_before_action :refuse_when_done
  before_action :require_gm

  def create
    Current.campaign.mark_done!(by: Current.identity)
    redirect_to Current.campaign, notice: "#{Current.campaign.name} is done. It stays here to look back on."
  rescue ArgumentError => error
    redirect_to edit_campaign_path(Current.campaign), alert: error.message
  end

  def destroy
    Current.campaign.reopen!(by: Current.identity)
    redirect_to Current.campaign, notice: "#{Current.campaign.name} is open again."
  rescue ArgumentError => error
    redirect_to edit_campaign_path(Current.campaign), alert: error.message
  end
end
