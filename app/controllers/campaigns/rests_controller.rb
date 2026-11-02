# A rest (pg. 31): marks and harm clear for the characters there. GM only.
class Campaigns::RestsController < ApplicationController
  include CampaignScoped
  before_action :refuse_when_on_hold

  before_action :require_gm

  def create
    Current.campaign.rest!(by: Current.identity)
    back_to_table(anchor: "roll-log", notice: "Everyone rests.")
  end
end
