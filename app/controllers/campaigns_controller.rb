class CampaignsController < ApplicationController
  include CampaignScoped

  skip_before_action :set_campaign, only: %i[ index create ]
  before_action :require_gm, only: %i[ update destroy ]

  def index
    @memberships = Current.identity.memberships.includes(:campaign).order(created_at: :desc)
    @campaign = Campaign.new
  end

  def create
    @campaign = Campaign.create_with_gm!(name: params.expect(campaign: [ :name ])[:name], gm: Current.identity)
    redirect_to @campaign, notice: "Campaign started. Share the join link with your players."
  rescue ActiveRecord::RecordInvalid => error
    @campaign = error.record.is_a?(Campaign) ? error.record : Campaign.new
    @memberships = Current.identity.memberships.includes(:campaign).order(created_at: :desc)
    render :index, status: :unprocessable_entity
  end

  def show
    @memberships = Current.campaign.memberships.includes(:identity).order(:role, :created_at)
    @characters = Current.campaign.characters.includes(:identity).ordered
  end

  def update
    if Current.campaign.update(params.expect(campaign: [ :name ]))
      redirect_to Current.campaign, notice: "Campaign renamed."
    else
      @memberships = Current.campaign.memberships.includes(:identity).order(:role, :created_at)
      @characters = Current.campaign.characters.includes(:identity).ordered
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    Current.campaign.destroy
    redirect_to campaigns_path, notice: "Campaign deleted."
  end

  private
    def campaign_id_param
      params[:id]
    end
end
