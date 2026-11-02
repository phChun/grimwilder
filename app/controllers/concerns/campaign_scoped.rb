# Loads the campaign named in the URL through the signed-in identity's
# memberships, so anyone who isn't a member gets a 404. Sets Current.campaign
# and Current.membership for the rest of the request.
module CampaignScoped
  extend ActiveSupport::Concern

  included do
    require_authentication
    before_action :set_campaign
    before_action :refuse_when_archived, unless: -> { request.get? || request.head? }
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

    # An archived campaign (Campaign::Archive) is read-only: reading works, changing
    # doesn't. Controllers that may still change one (settings, leaving,
    # unarchiving) skip this.
    def refuse_when_archived
      if Current.campaign&.archived?
        redirect_back_or_to campaign_path(Current.campaign), status: :see_other, alert: "#{Current.campaign.name} is archived. The GM can unarchive it to play."
      end
    end

    def gm?
      Current.membership&.gm?
    end

    def require_gm
      head :forbidden unless gm?
    end

    # Where play happens for this viewer: the GM table, or the campaign page
    # (for everyone, once the campaign is archived).
    def table_path_for_viewer(anchor: nil)
      gm? && !Current.campaign.archived? ? campaign_table_path(Current.campaign, anchor: anchor) : campaign_path(Current.campaign, anchor: anchor)
    end

    # Back where play happens; a player who rolled from their sheet (it holds
    # the table's pools and group rolls) goes back to it.
    def back_to_table(anchor: nil, **options)
      if (sheet = sheet_rolled_from)
        redirect_to character_path(sheet, anchor: "table-rolls"), **options
      else
        redirect_to table_path_for_viewer(anchor: anchor), **options
      end
    end

    def sheet_rolled_from
      id = URI(request.referer.to_s).path[%r{\A/characters/(\d+)\z}, 1] rescue nil
      id && Current.campaign.characters.where(identity: Current.identity).find_by(id: id)
    end
end
