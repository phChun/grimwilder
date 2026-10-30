# Expanded downtime (Character::Goals): letting a goal go, reached or not.
# The owner and the campaign's GM.
class Characters::GoalsController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_done

  def destroy
    goal = @character.goal_pools.find(params[:id])
    goal.destroy!
    redirect_to character_path(@character, anchor: "talent-rule"), notice: "#{goal.name} let go."
  end
end
