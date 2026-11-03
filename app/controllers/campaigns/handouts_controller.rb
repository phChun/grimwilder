# The GM shares an image with the whole table, from the GM table's Share fold:
# a handout line in the chat (Message, kind handout), with an optional caption.
class Campaigns::HandoutsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def create
    Current.campaign.messages.create!(identity: Current.identity, kind: "handout", image: params[:image].presence, body: params[:caption].to_s)
    redirect_to campaign_table_path(Current.campaign, anchor: "share"), notice: "Handout shared with the table."
  end
end
