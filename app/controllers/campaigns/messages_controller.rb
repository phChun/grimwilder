# Table chat. Anyone at the table can post, as themselves or as one of their
# own characters seated here. The new line reaches everyone, the sender
# included, over the chat stream, so a Turbo submit gets nothing back but the
# form being cleared.
class Campaigns::MessagesController < ApplicationController
  include CampaignScoped

  def create
    Current.campaign.messages.create!(identity: Current.identity, character: speaker, body: params[:body])

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back_or_to campaign_path(Current.campaign) }
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back_or_to campaign_path(Current.campaign), alert: error.record.errors.full_messages.to_sentence }
    end
  end

  private
    # Only your own characters seated at this table; the model checks it too.
    def speaker
      Current.identity.characters.where(campaign: Current.campaign).find(params[:character_id]) if params[:character_id].present?
    end
end
