# Story rolls from the campaign page: anyone at the table, for one of their own
# seated characters or for no one (the GM testing luck, say).
class Campaigns::StoryRollsController < ApplicationController
  include CampaignScoped

  def create
    character = Current.identity.characters.where(campaign: Current.campaign).find(params[:character_id]) if params[:character_id].present?

    Roll.story!(
      campaign: Current.campaign, by: Current.identity, character: character, question: params[:question],
      odds: (params[:odds].presence || 2).to_i, thorns: params[:thorns].to_i, spend_spark: params[:spark].to_i
    )
    redirect_to campaign_path(Current.campaign, anchor: "roll-log")
  rescue ArgumentError => error
    redirect_to campaign_path(Current.campaign, anchor: "story-roll"), alert: error.message
  end
end
