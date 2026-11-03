# Scene blocks (SceneBlock): prepared scenes grouped by where the players
# might go, on the scene prep page. GM only.
class Campaigns::SceneBlocksController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_block, only: %i[ edit update destroy ]

  def create
    block = Current.campaign.scene_blocks.new(block_params)
    if block.save
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(block)), notice: "#{block.title} is ready for scenes."
    else
      redirect_to campaign_scene_plans_path(Current.campaign), alert: block.errors.full_messages.to_sentence
    end
  end

  def edit
  end

  def update
    if @block.update(block_params)
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(@block)), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @block.destroy
    redirect_to campaign_scene_plans_path(Current.campaign), notice: "#{@block.title} removed. Its scenes are still in your prep."
  end

  private
    def set_block
      @block = Current.campaign.scene_blocks.find(params[:id])
    end

    def block_params
      params.expect(scene_block: [ :title, :notes ])
    end
end
