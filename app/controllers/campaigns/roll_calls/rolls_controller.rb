# Rolling at a roll call: a player rolls their own character's dice with the
# spark they pick, or the GM rolls for one character, or for everyone left.
class Campaigns::RollCalls::RollsController < Campaigns::RollCallsController
  def create
    call = Current.campaign.roll_calls.open.find(params[:roll_call_id])
    if params[:everyone] == "1"
      call.roll_everyone!(by: Current.identity)
    else
      call.roll!(Current.campaign.characters.find(params[:character_id]), by: Current.identity, spark: params[:spark].to_i)
    end
    redirect_to campaign_roll_call_path(Current.campaign)
  rescue ArgumentError, ActiveRecord::RecordNotFound => error
    render_call_error(error)
  end
end
