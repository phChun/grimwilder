# The star under an in-character line or narration: nominate it as a best
# moment, which fills in the moment prompt when the next session starts.
class Campaigns::Messages::NominationsController < ApplicationController
  include CampaignScoped

  def create
    message = Current.campaign.messages.visible_to(Current.membership).find(params[:message_id])
    nomination = PlaySession::Nomination.nominate!(message, by: Current.identity)

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back_or_to table_path_for_viewer, notice: "Starred for #{nomination.character.name}'s best moment." }
    end
  rescue ArgumentError => error
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back_or_to table_path_for_viewer, alert: error.message }
    end
  end
end
