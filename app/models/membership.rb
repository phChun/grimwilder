# An identity's seat at a campaign: the GM who runs it, or a player.
class Membership < ApplicationRecord
  belongs_to :campaign
  belongs_to :identity

  enum :role, { gm: "gm", player: "player" }, default: :player, validate: true

  validates :identity_id, uniqueness: { scope: :campaign_id }

  before_destroy :ensure_campaign_keeps_a_gm
  after_destroy :unseat_characters

  private
    # Someone who leaves (or is removed from) a campaign takes their characters with them.
    def unseat_characters
      identity.characters.where(campaign: campaign).update_all(campaign_id: nil) unless destroyed_by_association
    end

    def ensure_campaign_keeps_a_gm
      if gm? && !destroyed_by_association && campaign.memberships.gm.where.not(id: id).none?
        errors.add(:base, "A campaign needs at least one GM")
        throw :abort
      end
    end
end
