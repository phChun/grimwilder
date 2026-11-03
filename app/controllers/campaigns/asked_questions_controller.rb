# The question waiting on this player, as a Turbo Frame: each player loads
# their own copy when a question is asked or closed (TableQuestion broadcasts a
# frame pointing here), and their answer's form posts back into it.
class Campaigns::AskedQuestionsController < ApplicationController
  include CampaignScoped

  def show
    render partial: "table_questions/frame", locals: { campaign: Current.campaign, answer: TableQuestion.showing_for(Current.campaign, Current.membership) }
  end
end
