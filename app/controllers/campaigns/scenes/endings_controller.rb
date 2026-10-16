# Ending a scene: maybe close it with a montage, note what happened, and clear
# the "clears after scene" conditions the GM leaves ticked. GM only.
class Campaigns::Scenes::EndingsController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_scene

  def new
    @montages = @scene.rolls.montage.recent
  end

  def create
    closing = @scene.rolls.montage.find(params[:closing_roll_id]) if params[:closing_roll_id].present?
    @scene.end!(by: Current.identity, clear: Array(params[:clear]), notes: params[:notes], closing_roll: closing)
    redirect_to campaign_path(Current.campaign, anchor: "roll-log")
  rescue ArgumentError => error
    redirect_to campaign_path(Current.campaign), alert: error.message
  end

  private
    def set_scene
      @scene = Current.campaign.scenes.find(params[:scene_id])
    end
end
