# The Milestone levels optional rule (pg. 177, Campaign::Breaks#milestone!):
# after a major group arc, the party levels up. GM only.
class Campaigns::MilestonesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    levelled = Current.campaign.milestone!(by: Current.identity)
    back_to_table(anchor: "roll-log", notice: levelled.any? ? "#{levelled.map(&:name).to_sentence} reached a new level." : "Nobody had a level to gain.")
  rescue ArgumentError => error
    back_to_table(alert: error.message)
  end
end
