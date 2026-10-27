# The Rest resets optional rule (pg. 175, Campaign::Breaks#rest_reset!): at a
# rest, spark, talents, thread and 1 harm for the characters there. GM only.
class Campaigns::RestResetsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    Current.campaign.rest_reset!(by: Current.identity)
    back_to_table(anchor: "roll-log", notice: "Everyone resets: spark, talents, thread and 1 harm.")
  rescue ArgumentError => error
    back_to_table(alert: error.message)
  end
end
