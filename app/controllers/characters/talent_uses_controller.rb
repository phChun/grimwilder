# Ticking a talent's uses on the sheet (Character::TalentUses). The owner and
# the campaign's GM can; it's server state, so the table sees it too. When the
# GM has turned on Campaign#log_talent_uses, each use spent goes in the table
# log as well.
class Characters::TalentUsesController < ApplicationController
  require_authentication

  before_action :set_character
  before_action :refuse_when_campaign_archived

  # spent: how many are spent, or for a named use (Hidden Magic's words),
  # name: the box to burn or restore.
  def update
    use_id = params.expect(:use)
    before = @character.use_counters.find { _1.id == use_id }&.then { @character.uses_spent(_1) } || 0
    use = params[:name].present? ? @character.toggle_named_use!(use_id, params[:name]) : @character.spend_use!(use_id, spent: params[:spent])

    if @character.campaign&.log_talent_uses? && @character.uses_spent(use) > before
      spent = params[:name].present? ? "burns #{params[:name]}" : "spends #{use.label.downcase}"
      Roll.note!(campaign: @character.campaign, by: Current.identity, character: @character, text: "#{@character.name} #{spent}")
    end
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-#{use.talent_key}")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talents"), alert: error.message
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      head :forbidden unless helpers.can_spend_talent_uses?(@character)
    end
end
