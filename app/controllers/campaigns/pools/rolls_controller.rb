# Roll a pool: drop every die showing 1–3. A power pool can instead be rolled
# as an action roll (pg. 19), with thorns, and spark from one of your own
# seated characters.
class Campaigns::Pools::RollsController < ApplicationController
  include PoolScoped

  def create
    drop_first = params[:drop_first] == "1"

    if drop_first && !@pool.drops_first_for?(gm: Current.membership.gm?)
      back_to_pools alert: "#{@pool.name} can't drop 1d before rolling."
    elsif @pool.rollable?
      @pool.roll!(by: Current.identity, drop_first: drop_first, **action_roll)
      back_to_pools
    else
      back_to_pools alert: "#{@pool.name} is at 0d. Reset it to roll again."
    end
  rescue ArgumentError => error
    back_to_pools alert: error.message
  end

  private
    def action_roll
      return {} unless params[:as_action] == "1"

      character = Current.identity.characters.where(campaign: Current.campaign).find(params[:character_id]) if params[:character_id].present?
      { as_action: true, thorns: params[:thorns].to_i, character: character, spend_spark: params[:spark].to_i }
    end
end
