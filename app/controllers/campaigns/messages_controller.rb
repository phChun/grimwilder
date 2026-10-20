# Table chat. The composer's speak-as picker sends speak_as: "narration",
# "npc" (with speaker_name), "table_talk", "whisper", or "character:<id>". The
# model decides who may speak which way. The new line reaches everyone who
# should see it, the sender included, over the chat streams, so a Turbo
# submit gets nothing back but the form being cleared.
class Campaigns::MessagesController < ApplicationController
  include CampaignScoped

  def create
    Current.campaign.messages.create!(identity: Current.identity, body: params[:body], **speaking)

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back_or_to table_path_for_viewer }
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back_or_to table_path_for_viewer, alert: error.record.errors.full_messages.to_sentence }
    end
  end

  private
    def speaking
      kind, character_id = params[:speak_as].to_s.split(":", 2)

      case kind
      when "character" then { kind: "in_character", character: Current.campaign.characters.find_by(id: character_id) }
      when "npc" then { kind: "npc", speaker_name: params[:speaker_name] }
      when *Message.kinds.keys then { kind: kind }
      else { kind: "table_talk" }
      end
    end
end
