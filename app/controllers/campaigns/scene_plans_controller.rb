# Scene prep (ScenePlan): the GM writes scenes ahead of play, each a title,
# notes and maybe a story roll question for when it opens, in a scene
# collection (SceneCollection) or loose, and picks one when starting a scene.
# New is the form that takes the Add a scene card's place on the prep page
# (its new_scene_plan frame); collection= picks a collection to start on. GM
# only.
class Campaigns::ScenePlansController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_plan, only: %i[ edit update destroy ]

  def index
    @collections = Current.campaign.scene_collections.ordered.includes(:scene_plans)
    @loose = Current.campaign.scene_plans.unplayed.loose.ordered
    @played = Current.campaign.scene_plans.played.includes(scene: :play_session).order(updated_at: :desc).limit(10)
  end

  def new
    @plan = Current.campaign.scene_plans.new(scene_collection: Current.campaign.scene_collections.find_by(id: params[:collection]))
  end

  def create
    @plan = Current.campaign.scene_plans.new(plan_params)
    if @plan.save
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(@plan)), notice: "#{@plan.title} is ready to play."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(@plan)), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plan.destroy
    redirect_to campaign_scene_plans_path(Current.campaign), notice: "#{@plan.title} removed."
  end

  private
    def set_plan
      @plan = Current.campaign.scene_plans.find(params[:id])
    end

    # A scene can move to another collection on its own (the list's Collection
    # select), so each field is only set when it's sent.
    def plan_params
      params.expect(scene_plan: [ :title, :notes, :story_question, :scene_collection_id ]).tap do |permitted|
        permitted[:scene_collection] = Current.campaign.scene_collections.find_by(id: permitted.delete(:scene_collection_id)) if permitted.key?(:scene_collection_id)
      end
    end
end
