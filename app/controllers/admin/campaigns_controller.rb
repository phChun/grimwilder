# Every campaign, read-only, searchable by name, 50 a page. Admins aren't let in to campaigns they aren't
# members of; this is only the overview.
class Admin::CampaignsController < Admin::BaseController
  def index
    campaigns = search(Campaign.order(Arel.sql("archived_at IS NOT NULL"), created_at: :desc), "name")
    @pagy, page = pagy(:offset, campaigns, limit: PER_PAGE)
    @campaigns = page.includes(memberships: :identity).to_a
    ids = @campaigns.map(&:id)
    @character_counts = Character.played.active.where(campaign_id: ids).group(:campaign_id).count
    @session_counts = PlaySession.where(campaign_id: ids).group(:campaign_id).count
    @last_rolls = Roll.where(campaign_id: ids).group(:campaign_id).maximum(:created_at)
  end
end
