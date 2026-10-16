# Story rolls from the campaign page: anyone at the table, for one of their own
# seated characters or for no one (the GM testing luck, say).
class Campaigns::StoryRollsController < ApplicationController
  include CampaignScoped, StoryRollParams

  def create
    Roll.story!(campaign: Current.campaign, by: Current.identity, **story_roll_args)
    redirect_to campaign_path(Current.campaign, anchor: "roll-log")
  rescue ArgumentError => error
    redirect_to campaign_path(Current.campaign, anchor: "story-roll"), alert: error.message
  end
end
