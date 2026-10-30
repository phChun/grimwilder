# Expanded downtime (Character::Goals): spending the thread from planning
# ahead. The owner and the campaign's GM.
class Characters::PlanThreadsController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_done

  def destroy
    @character.spend_plan_thread!(by: Current.identity)
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-rule")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-rule"), alert: error.message
  end
end
