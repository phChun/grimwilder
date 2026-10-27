# Scene prep (ScenePlan): the GM writes scenes ahead of play, each a title,
# notes and maybe an opening story roll, and picks one when starting a scene.
# GM only.
class Campaigns::ScenePlansController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_plan, only: %i[ edit update destroy ]

  def index
    @plan = Current.campaign.scene_plans.new
    load_plans
  end

  def create
    @plan = Current.campaign.scene_plans.new(plan_params)
    if @plan.save
      redirect_to campaign_scene_plans_path(Current.campaign), notice: "#{@plan.title} is ready to play."
    else
      load_plans
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to campaign_scene_plans_path(Current.campaign), notice: "Saved."
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

    def load_plans
      @plans = Current.campaign.scene_plans.unplayed.ordered
      @played = Current.campaign.scene_plans.played.includes(scene: :play_session).order(updated_at: :desc).limit(10)
    end

    def plan_params
      params.expect(scene_plan: [ :title, :notes, :opening_question, :opening_odds ]).tap do |permitted|
        permitted[:opening_odds] = permitted[:opening_odds].presence
      end
    end
end
