# Feedback from the accounts allowed to send it, newest first and searchable
# by its words, page or route, 50 a page; and all of what's found as Markdown
# to copy for an AI (Feedback.to_markdown).
class Admin::FeedbacksController < Admin::BaseController
  MARKDOWN_LIMIT = 500 # items in the copy box, newest first

  def index
    found = search(Feedback.newest_first, "body", "path", "route")
    @pagy, feedbacks = pagy(:offset, found, limit: PER_PAGE)
    @feedbacks = feedbacks.includes(:identity).to_a
    @markdown = Feedback.to_markdown(found.includes(:identity).limit(MARKDOWN_LIMIT))
    @senders = Identity.where(feedback_enabled: true).order(:name, :email_address)
  end

  def destroy
    Feedback.find(params[:id]).destroy
    redirect_to admin_feedbacks_path(q: params[:q].presence), notice: "Feedback removed."
  end
end
