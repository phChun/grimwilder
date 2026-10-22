# Characters up for grabs. The GM can make a character for the table, or take
# back any character in the campaign, and offer it to the players: the GM
# holds it (as its owner) until a member of the table picks it and becomes
# its owner. A player can give theirs back the same way. Up-for-grabs
# characters aren't in the party: they're left out of attendance, rests,
# downtime, group rolls, assists and the rail's speak-as until picked.
module Character::Claiming
  extend ActiveSupport::Concern

  included do
    scope :up_for_grabs, -> { where(up_for_grabs: true) }
    scope :played, -> { where(up_for_grabs: false) }

    validate :offered_by_a_gm, if: :up_for_grabs?
  end

  # Anyone at the table may pick one while it's up for grabs.
  def claimable_by?(identity)
    (up_for_grabs? && campaign && identity&.membership_in(campaign).present?) || false
  end

  # The campaign's GM, or the player who has it, while they're still playing.
  def releasable_by?(identity)
    (campaign.present? && !up_for_grabs? && active? && tended_by?(identity)) || false
  end

  def claim!(by:)
    with_lock do
      raise ArgumentError, "Someone else picked #{name} first." unless claimable_by?(by)
      update!(identity: by, up_for_grabs: false)
    end
  end

  # Back to a GM to hold: the one doing it, or for a player giving theirs
  # back, the campaign's first GM.
  def release!(by:)
    raise ArgumentError, "#{name} isn't yours to give up." unless releasable_by?(by)

    gm = by.membership_in(campaign).gm? ? by : campaign.gms.first
    update!(identity: gm, up_for_grabs: true)
  end

  private
    def offered_by_a_gm
      errors.add(:up_for_grabs, "needs a campaign you GM") unless campaign && identity&.membership_in(campaign)&.gm?
    end
end
