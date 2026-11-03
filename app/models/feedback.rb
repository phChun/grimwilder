# What someone told us about the app from the header's Feedback button (only
# accounts an admin has turned it on for, identities.feedback_enabled), with
# the page they were on. Admins read it in /admin/feedback and copy it out as
# Markdown (Feedback.to_markdown) for an AI to sort through.
class Feedback < ApplicationRecord
  BODY_LIMIT = 5_000

  belongs_to :identity

  normalizes :body, with: ->(value) { value.strip }
  normalizes :path, with: ->(value) { value.to_s.strip }

  validates :body, presence: true, length: { maximum: BODY_LIMIT }
  validates :path, presence: true, length: { maximum: 2_000 }
  validate :path_is_on_this_site

  before_save { self.route = self.class.route_for(path) }
  before_save { self.user_agent = user_agent.to_s.first(500).presence }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # "/campaigns/3/table?x=1" to "campaigns/tables#show", or nil.
  def self.route_for(path)
    recognized = Rails.application.routes.recognize_path(path.to_s.split("?").first)
    "#{recognized[:controller]}##{recognized[:action]}" if recognized[:controller]
  rescue ActionController::RoutingError
    nil
  end

  # Only a path on this site, never somewhere else ("//evil.example").
  def self.local_path?(path)
    path.to_s.start_with?("/") && !path.to_s.start_with?("//")
  end

  # The list as Markdown for an AI to read: who (by name only), when, where
  # (the page and its route), the browser, and their words.
  def self.to_markdown(feedbacks, exported_at: Time.current)
    items = feedbacks.to_a
    lines = [
      "# Grimwilder feedback", "",
      "#{items.size} #{"item".pluralize(items.size)}, newest first, exported #{exported_at.utc.strftime("%Y-%m-%d %H:%M UTC")}. " \
        "Grimwilder is a Rails app; each item names the page the person was on and the controller action behind it.", ""
    ]
    items.each_with_index do |feedback, index|
      lines << "## #{index + 1}. #{feedback.path}" << ""
      lines << "- From: #{feedback.identity.display_name}"
      lines << "- When: #{feedback.created_at.utc.strftime("%Y-%m-%d %H:%M UTC")}"
      lines << "- Route: `#{feedback.route}`" if feedback.route
      lines << "- Browser: #{feedback.user_agent}" if feedback.user_agent
      lines << "" << feedback.body.lines.map { "> #{_1.chomp}".rstrip }.join("\n") << ""
    end
    lines.join("\n")
  end

  private
    def path_is_on_this_site
      errors.add(:path, "must be a page on this site") unless self.class.local_path?(path)
    end
end
