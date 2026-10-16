# A campaign's pools. Every member sees and rolls the visible ones; the GM
# creates, hides, renames and deletes them.
class Campaigns::PoolsController < ApplicationController
  include CampaignScoped

  before_action :require_gm, except: :index
  before_action :set_pool, only: %i[ update destroy ]
  before_action :set_table_log, only: %i[ index create ]

  def index
    @pools = Current.campaign.pools.visible_to(Current.membership).includes(:last_rolled_by).ordered
    @pool = Current.campaign.pools.new(starting_size: 4)
  end

  def create
    @pool = Current.campaign.pools.new(pool_params)

    if @pool.save
      redirect_to campaign_pools_path(Current.campaign)
    else
      @pools = Current.campaign.pools.visible_to(Current.membership).includes(:last_rolled_by).ordered
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @pool.update!(params.expect(pool: [ :hidden ]))
    redirect_to campaign_pools_path(Current.campaign)
  end

  def destroy
    @pool.destroy
    redirect_to campaign_pools_path(Current.campaign), notice: "#{@pool.name} removed."
  end

  private
    def set_pool
      @pool = Current.campaign.pools.find(params[:id])
    end

    def pool_params
      params.expect(pool: [ :name, :kind, :starting_size, :hidden ])
    end

    def set_table_log
      @rolls = Current.campaign.rolls.table_log(Current.membership, limit: 20)
    end
end
