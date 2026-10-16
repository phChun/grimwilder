# A campaign's pools. They're run from the campaign page (the GM table), so
# the old pools page sends people there. Every member sees and rolls the
# visible ones; the GM creates, hides and deletes them.
class Campaigns::PoolsController < ApplicationController
  include CampaignScoped, CampaignTable

  before_action :require_gm, except: :index
  before_action :set_pool, only: %i[ update destroy ]

  def index
    redirect_to campaign_path(Current.campaign, anchor: "pools")
  end

  def create
    @pool = Current.campaign.pools.new(pool_params)

    if @pool.save
      redirect_to campaign_path(Current.campaign, anchor: helpers.dom_id(@pool))
    else
      load_table
      render "campaigns/show", status: :unprocessable_entity
    end
  end

  def update
    @pool.update!(params.expect(pool: [ :hidden ]))
    redirect_to campaign_path(Current.campaign, anchor: helpers.dom_id(@pool))
  end

  def destroy
    @pool.destroy
    redirect_to campaign_path(Current.campaign, anchor: "pools"), notice: "#{@pool.name} removed."
  end

  private
    def set_pool
      @pool = Current.campaign.pools.find(params[:id])
    end

    def pool_params
      params.expect(pool: [ :name, :kind, :starting_size, :phases_text, :hidden ])
    end
end
