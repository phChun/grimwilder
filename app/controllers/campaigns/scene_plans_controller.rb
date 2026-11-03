# Scene prep (ScenePlan): the GM writes scenes ahead of play, each a title,
# notes and maybe an opening story roll, in a block (SceneBlock) or loose,
# and picks one when starting a scene. GM only.
class Campaigns::ScenePlansController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_plan, only: %i[ edit update destroy ]

  def index
    @plan = Current.campaign.scene_plans.new(scene_block_id: params[:block])
    load_plans
  end

  def create
    @plan = Current.campaign.scene_plans.new(plan_params)
    if @plan.save
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(@plan)), notice: "#{@plan.title} is ready to play."
    else
      load_plans
      render :index, status: :unprocessable_entity
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

    def load_plans
      @blocks = Current.campaign.scene_blocks.ordered.includes(:scene_plans)
      @loose = Current.campaign.scene_plans.unplayed.loose.ordered
      @played = Current.campaign.scene_plans.played.includes(scene: :play_session).order(updated_at: :desc).limit(10)
    end

    # A scene can move to another block on its own (the list's Block select),
    # so each field is only set when it's sent.
    def plan_params
      params.expect(scene_plan: [ :title, :notes, :opening_question, :opening_odds, :scene_block_id ]).tap do |permitted|
        permitted[:opening_odds] = permitted[:opening_odds].presence if permitted.key?(:opening_odds)
        permitted[:scene_block] = Current.campaign.scene_blocks.find_by(id: permitted.delete(:scene_block_id)) if permitted.key?(:scene_block_id)
      end
    end
end
