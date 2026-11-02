# The GM's changes to the dates in Coming up (Campaign::Schedule): skip or
# move one of the rule's dates (named by its date, 2026-11-07) and undo that,
# or add an extra date (named by its id), move it or remove it.
class Campaigns::GameDatesController < ApplicationController
  include CampaignScoped

  before_action :require_gm, :set_schedule

  def create
    @schedule.add!(date: date_param(:date), time: time_param, note: params[:note])
    redirect_back_or_to Current.campaign, notice: "Date added."
  end

  def update
    if (date = rule_date)
      if params[:change] == "skip"
        @schedule.skip!(date, note: params[:note])
      else
        @schedule.move!(date, to: date_param(:date), time: time_param, note: params[:note])
      end
    else
      @schedule.move_extra!(extra, to: date_param(:date), time: time_param, note: params[:note])
    end
    redirect_back_or_to Current.campaign, notice: params[:change] == "skip" ? "Date skipped." : "Date moved."
  rescue ArgumentError => error
    redirect_back_or_to Current.campaign, alert: error.message
  end

  def destroy
    if (date = rule_date) then @schedule.undo!(date)
    else extra.destroy!
    end
    redirect_back_or_to Current.campaign, notice: rule_date ? "Back on the schedule." : "Date removed."
  end

  private
    def set_schedule
      @schedule = Current.campaign.schedule or redirect_to edit_campaign_path(Current.campaign, anchor: "settings-schedule"), alert: "Set a schedule first."
    end

    def rule_date
      Date.iso8601(params[:id]) if params[:id].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    end

    def extra
      Current.campaign.game_dates.extra.find(params[:id])
    end

    def date_param(name)
      Date.iso8601(params.expect(name))
    rescue Date::Error
      raise ActionController::ParameterMissing, name
    end

    # "19:30", or the schedule's usual time.
    def time_param
      time = params[:time].to_s
      time.match?(/\A([01]\d|2[0-3]):[0-5]\d\z/) ? time : @schedule.start_time
    end
end
