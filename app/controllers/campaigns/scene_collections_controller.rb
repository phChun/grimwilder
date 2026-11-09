# Scene collections (SceneCollection): prepared scenes grouped by where the
# players might go, on the scene prep page. New is the form that takes the
# "Create new scene collection" button's place there (its new_scene_collection
# frame). GM only.
class Campaigns::SceneCollectionsController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_collection, only: %i[ edit update destroy ]

  def new
    @collection = Current.campaign.scene_collections.new
  end

  def create
    @collection = Current.campaign.scene_collections.new(collection_params)
    if @collection.save
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(@collection)), notice: "#{@collection.title} is ready for scenes."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @collection.update(collection_params)
      redirect_to campaign_scene_plans_path(Current.campaign, anchor: helpers.dom_id(@collection)), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to campaign_scene_plans_path(Current.campaign), notice: "#{@collection.title} removed. Its scenes are still in your prep, as individual scenes."
  end

  private
    def set_collection
      @collection = Current.campaign.scene_collections.find(params[:id])
    end

    def collection_params
      params.expect(scene_collection: [ :title, :notes ])
    end
end
