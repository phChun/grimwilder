# The GM closes a poll: it leaves the players' screens and takes no more answers.
class Campaigns::TableQuestions::ClosingsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    Current.campaign.table_questions.find(params[:question_id]).close!
    redirect_to campaign_table_path(Current.campaign, anchor: "share")
  end
end
