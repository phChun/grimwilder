# Settings › Schedule (Campaign::Schedule): how often the campaign plays, the
# day and time in a time zone, the first game, and a pause. GM only.
class Campaigns::SchedulesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def update
    schedule = Current.campaign.schedule || Current.campaign.build_schedule
    if schedule.update(schedule_params)
      redirect_to edit_campaign_path(Current.campaign, anchor: "settings-schedule"), notice: "Schedule saved."
    else
      redirect_to edit_campaign_path(Current.campaign, anchor: "settings-schedule"), alert: "That didn't save. #{schedule.errors.full_messages.to_sentence}."
    end
  end

  private
    def schedule_params
      params.expect(schedule: %i[ how_often weekday week_of_month starts_on start_time time_zone paused ])
    end
end
