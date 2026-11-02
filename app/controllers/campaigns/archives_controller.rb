# The GM archives the campaign (Campaign::Archive), making it read-only and
# no longer anyone's active campaign, or unarchives it. From settings, or
# from the campaigns list's ⋯ menu (return_to=campaigns brings it back there).
class Campaigns::ArchivesController < ApplicationController
  include CampaignScoped

  skip_before_action :refuse_when_archived
  before_action :require_gm

  def create
    Current.campaign.archive!(by: Current.identity)
    redirect_to back_after_archive, notice: "#{Current.campaign.name} is archived. It stays here to look back on."
  rescue ArgumentError => error
    redirect_to back_after_archive(failed: true), alert: error.message
  end

  def destroy
    Current.campaign.unarchive!(by: Current.identity)
    redirect_to back_after_archive, notice: "#{Current.campaign.name} is back from the archive."
  rescue ArgumentError => error
    redirect_to back_after_archive(failed: true), alert: error.message
  end

  private
    def back_after_archive(failed: false)
      if params[:return_to] == "campaigns" then campaigns_path
      elsif failed then edit_campaign_path(Current.campaign)
      else Current.campaign
      end
    end
end
