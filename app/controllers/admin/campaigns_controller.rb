# Every campaign, searchable by name, 50 a page, and deleting one for everyone. Admins aren't let in to
# campaigns they aren't members of; this is only the overview.
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

  # Deletes it for everyone, as its GM can from settings (campaigns#destroy).
  def destroy
    campaign = Campaign.find(params[:id])
    campaign.destroy!
    redirect_to admin_campaigns_path(q: params[:q].presence, page: params[:page].presence), notice: "#{campaign.name} deleted."
  end
end
