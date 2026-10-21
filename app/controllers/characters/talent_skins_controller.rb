# Re-skinning one of a character's talents (Character::TalentSkins): its own
# name, summary and text. The owner and the campaign's GM can, like talent uses.
class Characters::TalentSkinsController < ApplicationController
  require_authentication

  before_action :set_character

  def update
    @character.reskin_talent!(params[:talent_id], params.expect(skin: %i[ name summary text ]))
    back_to_talent
  end

  def destroy
    @character.reset_talent_skin!(params[:talent_id])
    back_to_talent
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      head :forbidden unless @character.tended_by?(Current.identity)
    end

    def back_to_talent
      @character.broadcast_refresh_later
      @character.campaign&.broadcast_table_refresh
      redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}")
    end
end
