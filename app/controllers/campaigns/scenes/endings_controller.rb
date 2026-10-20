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
    # "Cut to new scene" ends this one, then opens the next.
    if params[:then] == "new_scene"
      redirect_to new_campaign_scene_path(Current.campaign)
    else
      back_to_table(anchor: "roll-log")
    end
  rescue ArgumentError => error
    back_to_table(alert: error.message)
  end

  private
    def set_scene
      @scene = Current.campaign.scenes.find(params[:scene_id])
    end
end
