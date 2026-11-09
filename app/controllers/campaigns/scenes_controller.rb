# Starting a scene (pg. 96), maybe opening with a story roll: a scene with a
# story question opens the story roll modal on the table with it, for the GM
# to pick the odds and who rolls. GM only.
class Campaigns::ScenesController < ApplicationController
  include CampaignScoped
  before_action :refuse_when_on_hold, only: %i[ new create ] # editing a title or notes is fine

  before_action :require_gm
  before_action :set_session, only: %i[ new create ]

  # Lists the prepared scenes to start (each collection's, then the individual ones), or a new
  # one. plan=: a prepared scene (ScenePlan) fills in the form, to adjust first.
  def new
    @plan = Current.campaign.scene_plans.unplayed.find_by(id: params[:plan])
  end

  # as_written=1 starts a prepared scene as it was written (its title, notes
  # and story question); otherwise the form's fields say.
  def create
    raise ArgumentError, "Start a session first." unless @session

    plan = Current.campaign.scene_plans.unplayed.find_by(id: params[:scene_plan_id])
    scene =
      if plan && params[:as_written] == "1"
        Scene.start!(@session, title: plan.title, notes: plan.notes, story_question: plan.story_question, plan: plan, by: Current.identity)
      else
        Scene.start!(@session, title: params[:title], notes: params[:notes], story_question: params[:story_question], plan: plan, by: Current.identity)
      end
    flash[:open_modal] = new_campaign_story_roll_path(Current.campaign, question: scene.story_question) if scene.story_question
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
      @choices = @session&.scene_choices || []
      @last_collection = Current.campaign.last_scene_collection
    end
end
