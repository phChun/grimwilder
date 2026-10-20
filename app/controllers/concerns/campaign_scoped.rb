# Loads the campaign named in the URL through the signed-in identity's
# memberships, so anyone who isn't a member gets a 404. Sets Current.campaign
# and Current.membership for the rest of the request.
module CampaignScoped
  extend ActiveSupport::Concern

  included do
    require_authentication
    before_action :set_campaign
    helper_method :gm?, :table_path_for_viewer
  end

  private
    def set_campaign
      Current.membership = Current.identity.memberships.includes(:campaign).find_by!(campaign_id: campaign_id_param)
      Current.campaign = Current.membership.campaign
    end

    def campaign_id_param
      params[:campaign_id]
    end

    def gm?
      Current.membership&.gm?
    end

    def require_gm
      head :forbidden unless gm?
    end

    # Where play happens for this viewer: the GM table, or the campaign page.
    def table_path_for_viewer(anchor: nil)
      gm? ? campaign_table_path(Current.campaign, anchor: anchor) : campaign_path(Current.campaign, anchor: anchor)
    end

    def back_to_table(anchor: nil, **options)
      redirect_to table_path_for_viewer(anchor: anchor), **options
    end
end
