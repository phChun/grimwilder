# Everything the GM table (campaigns#show) shows: who's at the table, pools,
# the table feed (log and chat), and the crucibles. Pool actions that fail validation
# show the table again, so they load it too.
module CampaignTable
  private
    def load_table
      @memberships = Current.campaign.memberships.includes(:identity).order(:role, :created_at)
      @characters = Current.campaign.characters.played.active.includes(:identity).ordered
      @up_for_grabs = Current.campaign.characters.up_for_grabs.ordered
      @my_characters = @characters.select { _1.owned_by?(Current.identity) }
      @pools = Current.campaign.pools.shared.visible_to(Current.membership).includes(:last_rolled_by).ordered
      @talent_pools = Current.campaign.pools.talent.includes(:last_rolled_by).ordered.group_by(&:character_id)
      @pool ||= Current.campaign.pools.new(starting_size: 4)
      @feed = TableFeed.new(Current.campaign, Current.membership)
      @crucible_groups = Crucible.grouped
      @session = Current.campaign.current_session
    end
end
