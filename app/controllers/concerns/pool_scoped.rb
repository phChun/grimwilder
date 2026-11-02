# Finds the pool named in the URL among the ones this member may see.
module PoolScoped
  extend ActiveSupport::Concern

  included do
    include CampaignScoped
    before_action :refuse_when_on_hold
    before_action :set_pool
  end

  private
    def set_pool
      @pool = Current.campaign.pools.visible_to(Current.membership).find(params[:pool_id])
    end

    # Back to the table, or to the sheet when a talent or arcana pool was rolled there.
    def back_to_pools(**options)
      if params[:return_to] == "character" && @pool.character
        anchor = @pool.arcanum_id ? "arcanum-#{@pool.arcanum_id}" : "talent-#{@pool.use_key.to_s.split("/").first}"
        redirect_to helpers.character_path(@pool.character, anchor: anchor), **options
      else
        back_to_table(anchor: helpers.dom_id(@pool), **options)
      end
    end
end
