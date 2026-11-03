# The header's Feedback button: a box for what someone thinks, with the page
# they were on. Only for accounts an admin turned it on for; anyone else gets
# a 404. It opens in the frame modal, and saving goes back to that page.
class FeedbacksController < ApplicationController
  require_authentication
  before_action :require_feedback_enabled
  rate_limit to: 20, within: 1.hour, only: :create, with: -> { redirect_back_or_to root_path, alert: "That's a lot of feedback. Try again in an hour." }

  def new
    @feedback = Current.identity.feedbacks.new(path: page_path)
  end

  def create
    @feedback = Current.identity.feedbacks.new(params.expect(feedback: %i[ path body ]))
    @feedback.user_agent = request.user_agent
    if @feedback.save
      redirect_to @feedback.path, notice: "Thanks for the feedback."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_feedback_enabled
      raise ActiveRecord::RecordNotFound unless Current.identity.feedback_enabled?
    end

    # The page the button was pressed on (the header passes it); the home
    # page if it's missing or isn't one of ours.
    def page_path
      Feedback.local_path?(params[:path]) ? params[:path] : root_path
    end
end
