# Table chat; the GM can delete any line, and anyone their own. There's no
# picker for where a line goes: the rail's Show choice is the form's context.
# A story view ("all", "story", "dice") speaks to the table in character (the
# GM narrates, or voices an NPC with voice: "npc" and speaker_name; a player
# speaks as character_id, else their first character here, else table talk),
# "talk" is table talk, and "private-<side>" whispers to that side: "gm", or a
# player's identity id. The model decides who may speak which way. The new
# line reaches everyone who should see it, the sender included, over the chat
# streams, so a Turbo submit gets nothing back but the form being cleared.
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

  # The GM, or whoever wrote it, takes a line out of the chat, for everyone
  # who could see it (Message broadcasts the removal).
  def destroy
    message = Current.campaign.messages.visible_to(Current.membership).find(params[:id])
    return head :forbidden unless Current.membership.gm? || message.identity_id == Current.identity.id

    message.destroy!
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back_or_to table_path_for_viewer }
    end
  end

  private
    def speaking
      context = params[:context].to_s
      if (side = context[/\Aprivate-(.+)\z/, 1]) then whisper_to(side)
      elsif context == "talk" then { kind: "table_talk" }
      elsif Current.membership.gm?
        params[:voice] == "npc" ? { kind: "npc", speaker_name: params[:speaker_name] } : { kind: "narration" }
      elsif (character = speaking_character) then { kind: "in_character", character: character }
      else { kind: "table_talk" }
      end
    end

    # To the GM, or a player: by their first active character here when they
    # have one (it names them in the conversation).
    def whisper_to(side)
      return { kind: "whisper" } if side == "gm"

      player = Current.campaign.memberships.player.find_by(identity_id: side)&.identity
      character = player && Current.campaign.characters.played.active.where(identity: player).order(:name).first
      return { kind: "whisper", to_character: character } if character

      { kind: "whisper", recipient: player, recipient_name: player&.display_name }
    end

    def speaking_character
      mine = Current.campaign.characters.played.active.where(identity: Current.identity).order(:name)
      mine.find_by(id: params[:character_id]) || mine.first
    end
end
