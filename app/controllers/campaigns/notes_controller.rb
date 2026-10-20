# A short line in the table log ("Tibbs enters a frenzy"). Anyone at the table.
class Campaigns::NotesController < ApplicationController
  include CampaignScoped

  def create
    Roll.note!(campaign: Current.campaign, by: Current.identity, text: params[:text])
    back_to_table(anchor: "roll-log")
  rescue ActiveRecord::RecordInvalid
    back_to_table(anchor: "roll-log", alert: "Write something for the note.")
  end
end
