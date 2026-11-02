# The Roll button on a talent's card (Talent::Roll): spends what the talent
# asks, then calls the story roll or montage for the character, which the
# player rolls in the roll-call dialog.
class Characters::TalentRollsController < ApplicationController
  include CharacterScoped

  before_action :refuse_when_campaign_archived

  def create
    @character.call_talent_roll!(params[:talent_id], params[:index], by: Current.identity)
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}"), alert: error.message
  end
end
