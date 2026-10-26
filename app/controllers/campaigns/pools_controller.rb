# A campaign's pools. They're run from the campaign page (the GM table), so
# the old pools page sends people there. Every member sees and rolls the
# visible ones; the GM creates, hides and deletes them.
class Campaigns::PoolsController < ApplicationController
  include CampaignScoped, CampaignTable

  before_action :require_gm, except: :index
  before_action :set_pool, only: %i[ update destroy ]

  def index
    back_to_table(anchor: "pools")
  end

  def create
    @pool = Current.campaign.pools.new(pool_params)

    if @pool.save
      back_to_table(anchor: helpers.dom_id(@pool))
    else
      load_table
      render "campaigns/tables/show", status: :unprocessable_entity
    end
  end

  def update
    @pool.update!(params.expect(pool: [ :hidden ]))
    back_to_table(anchor: helpers.dom_id(@pool))
  end

  def destroy
    @pool.destroy
    back_to_table(anchor: "pools", notice: "#{@pool.name} removed.")
  end

  private
    def set_pool
      @pool = Current.campaign.pools.find(params[:id])
    end

    def pool_params
      params.expect(pool: [ :name, :kind, :starting_size, :phases_text, :hidden, :tick ])
    end
end
