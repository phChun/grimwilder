# Picking a character that's up for grabs, and putting one back up
# (Character::Claiming). Anyone at the table may pick; the GM may put any
# character in the campaign up for grabs, and a player may give theirs back.
class Characters::ClaimsController < ApplicationController
  require_authentication

  before_action :set_character

  def create
    @character.claim!(by: Current.identity)
    announce "#{Current.identity.display_name} picks #{@character.name}."
    redirect_to @character, notice: "#{@character.name} is yours to play."
  rescue ArgumentError => error
    redirect_to campaign_path(@character.campaign, anchor: "up-for-grabs"), alert: error.message
  end

  def destroy
    player = @character.identity
    @character.release!(by: Current.identity)
    announce(player == Current.identity ? "#{player.display_name} gives #{@character.name} back; up for grabs." : "#{Current.identity.display_name} puts #{@character.name} up for grabs.")
    redirect_to campaign_path(@character.campaign, anchor: "up-for-grabs"), notice: "#{@character.name} is up for grabs."
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      head :not_found unless @character.campaign
    end

    def announce(text)
      Roll.note!(campaign: @character.campaign, by: Current.identity, character: @character, text: text)
      @character.broadcast_refresh_later
      @character.campaign.broadcast_table_refresh
    end
end
