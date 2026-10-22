class CampaignsController < ApplicationController
  include CampaignScoped, CampaignTable

  OLDER_SESSIONS = 2

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

  # The campaign overview: what it's about, who's in it, what happened last
  # time. Players also roll pools and story rolls here, and follow the log.
  def show
    load_table
    load_overview
  end

  # Settings: the pitch, members and the invite link (the GM's), or leaving.
  def edit
    load_settings
  end

  def update
    if Current.campaign.update(campaign_params)
      redirect_to Current.campaign, notice: "Campaign saved."
    else
      load_settings
      render :edit, status: :unprocessable_entity
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

    def campaign_params
      params.expect(campaign: [ :name, :pitch, :setting, :party_never, :group_arc, party_is: [] ])
    end

    def load_settings
      @memberships = Current.campaign.memberships.includes(:identity).order(:role, :created_at)
    end

    def load_overview
      @party = @characters
      @gone = Current.campaign.characters.played.gone.includes(:identity).to_a
      ended = Current.campaign.play_sessions.ended.order(number: :desc).includes(scenes: [ :opening_roll, :closing_roll ])
      @previous = ended.first
      @older = ended.offset(1).limit(OLDER_SESSIONS).to_a
      @session_count = Current.campaign.play_sessions.count
      @hidden_pools = gm? ? @pools.count(&:hidden?) : 0
      @mine_all = Current.membership.seated_characters.to_a
      @mine = @mine_all.first
    end
end
