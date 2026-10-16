# Ticking a talent's uses on the sheet (Character::TalentUses). The owner and
# the campaign's GM can; it's server state, so the table sees it too.
class Characters::TalentUsesController < ApplicationController
  require_authentication

  before_action :set_character

  def update
    before = @character.talent_uses.fetch(params[:use].to_s, 0)
    use = @character.spend_use!(params.expect(:use), spent: params[:spent])

    if params[:note] == "1" && @character.uses_spent(use) > before && @character.campaign
      Roll.note!(campaign: @character.campaign, by: Current.identity, character: @character, text: "#{@character.name} spends #{use.label.downcase}")
    end
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-uses")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-uses"), alert: error.message
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      head :forbidden unless helpers.can_spend_talent_uses?(@character)
    end
end
