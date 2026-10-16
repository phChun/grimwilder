# Starting a scene (pg. 95), maybe opening with a story roll. GM only.
class Campaigns::ScenesController < ApplicationController
  include CampaignScoped, StoryRollParams

  before_action :require_gm
  before_action :set_session

  def new
  end

  def create
    raise ArgumentError, "Start a session first." unless @session

    Scene.start!(@session, title: params[:title], by: Current.identity, opening: (story_roll_args if params[:open_with_story] == "1"))
    redirect_to campaign_path(Current.campaign, anchor: "roll-log")
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_session
      @session = Current.campaign.current_session
      @my_characters = Current.campaign.characters.where(identity: Current.identity).ordered
    end
end
