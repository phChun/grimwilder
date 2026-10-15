# Finds the pool named in the URL among the ones this member may see.
module PoolScoped
  extend ActiveSupport::Concern

  included do
    include CampaignScoped
    before_action :set_pool
  end

  private
    def set_pool
      @pool = Current.campaign.pools.visible_to(Current.membership).find(params[:pool_id])
    end

    def back_to_pools(**options)
      redirect_to campaign_pools_path(Current.campaign, anchor: helpers.dom_id(@pool)), **options
    end
end
