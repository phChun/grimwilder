# Seating a character at one of its owner's campaigns, moving it to another,
# or taking it away from the table. Its talent pools go with it (or go away
# when it leaves every table), and each table it leaves or joins gets a note.
module Character::Seating
  extend ActiveSupport::Concern

  included do
    after_update :follow_with_talent_pools, if: :saved_change_to_campaign_id?
  end

  # The owner, unless the character is up for grabs (a GM holds those for the table).
  def seatable_by?(identity)
    owned_by?(identity) && !up_for_grabs?
  end

  # campaign: one of the owner's campaigns, or nil to leave the table.
  def seat!(campaign, by:)
    raise ArgumentError, "#{name} isn't yours to move." unless seatable_by?(by)

    left = self.campaign
    return if left == campaign

    transaction do
      update!(campaign: campaign)
      Roll.note!(campaign: left, by: by, text: "#{name} leaves the table.") if left
      Roll.note!(campaign: campaign, by: by, character: self, text: "#{by.display_name} seats #{name} at the table.") if campaign
    end

    [ left, campaign ].compact.each(&:broadcast_table_refresh)
  end

  private
    def follow_with_talent_pools
      campaign ? talent_pools.update_all(campaign_id: campaign_id) : talent_pools.destroy_all
    end
end
