# The roll call modal, as a Turbo Frame: each viewer loads their own copy when
# the call changes (RollCall broadcasts a frame pointing here). The GM or
# whoever called it can call it off.
class Campaigns::RollCallsController < ApplicationController
  include CampaignScoped

  def show
    @call = RollCall.showing_for(Current.campaign, Current.membership)
    render partial: "roll_calls/frame", locals: { campaign: Current.campaign, call: @call }
  end

  def destroy
    Current.campaign.roll_calls.open.find(params[:roll_call_id]).cancel!(by: Current.identity)
    redirect_to campaign_roll_call_path(Current.campaign)
  rescue ArgumentError, ActiveRecord::RecordNotFound => error
    render_call_error(error)
  end

  private
    # A call that has already finished or been called off isn't found.
    def render_call_error(error)
      message = error.is_a?(ActiveRecord::RecordNotFound) ? "That roll is over." : error.message
      render partial: "roll_calls/frame", locals: { campaign: Current.campaign, call: RollCall.showing_for(Current.campaign, Current.membership), error: message },
        status: :unprocessable_entity
    end
end
