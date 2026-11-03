# A player answers a question they were asked, or changes their answer, from
# the modal (table_questions/_call). Only the GM sees it.
class Campaigns::TableQuestions::AnswersController < ApplicationController
  include CampaignScoped

  def update
    answer = Current.membership.table_answers.joins(:table_question).merge(Current.campaign.table_questions).find_by!(table_question_id: params[:question_id])
    answer.answer!(choice: params[:choice], body: params[:body])
    redirect_to campaign_asked_question_path(Current.campaign)
  rescue ActiveRecord::RecordInvalid => error
    render partial: "table_questions/frame", status: :unprocessable_entity,
      locals: { campaign: Current.campaign, answer: error.record, error: error.record.errors.full_messages.to_sentence }
  end
end
