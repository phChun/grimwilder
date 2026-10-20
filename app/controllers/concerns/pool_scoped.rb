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

    # Back to the table, or to the sheet when a talent pool was rolled there.
    def back_to_pools(**options)
      if params[:return_to] == "character" && @pool.character
        redirect_to helpers.character_path(@pool.character, anchor: "talent-uses"), **options
      else
        back_to_table(anchor: helpers.dom_id(@pool), **options)
      end
    end
end
