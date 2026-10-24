# Every campaign, read-only. Admins aren't let in to campaigns they aren't
# members of; this is only the overview.
class Admin::CampaignsController < Admin::BaseController
  def index
    @campaigns = Campaign.includes(memberships: :identity).order(Arel.sql("done_at IS NOT NULL"), created_at: :desc)
    @character_counts = Character.played.active.group(:campaign_id).count
    @session_counts = PlaySession.group(:campaign_id).count
    @last_rolls = Roll.group(:campaign_id).maximum(:created_at)
  end
end
