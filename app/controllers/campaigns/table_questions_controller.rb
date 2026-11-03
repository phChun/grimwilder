# Polls, from the GM table's Share fold: the GM asks the players they tick
# (TableQuestion.ask!), or deletes a poll and its answers.
class Campaigns::TableQuestionsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    TableQuestion.ask!(campaign: Current.campaign, by: Current.identity, members: params[:members],
      body: params[:body], choices: params[:choices])
    redirect_to campaign_table_path(Current.campaign, anchor: "share"), notice: "Poll sent."
  end

  def destroy
    Current.campaign.table_questions.find(params[:id]).destroy!
    redirect_to campaign_table_path(Current.campaign, anchor: "share"), notice: "Poll deleted."
  end
end
