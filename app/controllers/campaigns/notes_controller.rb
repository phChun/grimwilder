# A short line in the table log ("Tibbs enters a frenzy"). Anyone at the table.
class Campaigns::NotesController < ApplicationController
  include CampaignScoped

  def create
    Roll.note!(campaign: Current.campaign, by: Current.identity, text: params[:text])
    redirect_to campaign_path(Current.campaign, anchor: "roll-log")
  rescue ActiveRecord::RecordInvalid
    redirect_to campaign_path(Current.campaign, anchor: "roll-log"), alert: "Write something for the note."
  end
end
