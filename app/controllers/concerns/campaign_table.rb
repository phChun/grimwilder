# Everything the GM table (campaigns#show) shows: who's at the table, pools,
# the newest log entries and the crucibles. Pool actions that fail validation
# show the table again, so they load it too.
module CampaignTable
  LOG_SIZE = 8

  private
    def load_table
      @memberships = Current.campaign.memberships.includes(:identity).order(:role, :created_at)
      @characters = Current.campaign.characters.includes(:identity).ordered
      @my_characters = @characters.select { _1.owned_by?(Current.identity) }
      @pools = Current.campaign.pools.visible_to(Current.membership).includes(:last_rolled_by).ordered
      @pool ||= Current.campaign.pools.new(starting_size: 4)
      @rolls = Current.campaign.rolls.table_log(Current.membership, limit: LOG_SIZE)
      @crucible_groups = Crucible.grouped
    end
end
