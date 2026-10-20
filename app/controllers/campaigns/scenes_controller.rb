# Starting a scene (pg. 95), maybe opening with a story roll. GM only.
class Campaigns::ScenesController < ApplicationController
  include CampaignScoped, StoryRollParams

  before_action :require_gm
  before_action :set_session, only: %i[ new create ]

  def new
  end

  def create
    raise ArgumentError, "Start a session first." unless @session

    Scene.start!(@session, title: params[:title], by: Current.identity, opening: (story_roll_args if params[:open_with_story] == "1"))
    back_to_table(anchor: "roll-log")
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  # The GM can retitle a scene or fill in its notes afterwards.
  def update
    scene = Current.campaign.scenes.find(params[:id])
    scene.update!(params.expect(scene: [ :title, :notes ]))
    redirect_to campaign_play_session_path(Current.campaign, scene.play_session, anchor: helpers.dom_id(scene)), notice: "Saved."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to campaign_play_session_path(Current.campaign, scene.play_session, anchor: helpers.dom_id(scene)), alert: error.message
  end

  private
    def set_session
      @session = Current.campaign.current_session
      @my_characters = Current.campaign.characters.where(identity: Current.identity).ordered
    end
end
