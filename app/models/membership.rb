# An identity's seat at a campaign: the GM who runs it, or a player.
class Membership < ApplicationRecord
  belongs_to :campaign
  belongs_to :identity

  enum :role, { gm: "gm", player: "player" }, default: :player, validate: true

  validates :identity_id, uniqueness: { scope: :campaign_id }

  before_destroy :ensure_campaign_keeps_a_gm
  after_destroy :unseat_characters

  # The character this member plays here, if they've seated one that's still playing.
  def seated_character
    identity.characters.where(campaign: campaign).played.active.ordered.first
  end

  private
    # Someone who leaves (or is removed from) a campaign takes their characters
    # with them, except ones up for grabs, which another GM holds from now on.
    def unseat_characters
      return if destroyed_by_association

      mine = identity.characters.where(campaign: campaign)
      if (gm = campaign.memberships.gm.where.not(id: id).first)
        mine.up_for_grabs.update_all(identity_id: gm.identity_id)
      end
      mine.update_all(campaign_id: nil, up_for_grabs: false)
    end

    def ensure_campaign_keeps_a_gm
      if gm? && !destroyed_by_association && campaign.memberships.gm.where.not(id: id).none?
        errors.add(:base, "A campaign needs at least one GM")
        throw :abort
      end
    end
end
