# An identity's seat at a campaign: the GM who runs it, or a player.
class Membership < ApplicationRecord
  belongs_to :campaign
  belongs_to :identity

  enum :role, { gm: "gm", player: "player" }, default: :player, validate: true

  validates :identity_id, uniqueness: { scope: :campaign_id }
  validate :one_active_campaign, on: :create

  before_destroy :ensure_campaign_keeps_a_gm
  after_destroy :unseat_characters

  # Each open page checks in this often (presence_controller.js); a member not
  # heard from for longer than PRESENCE_WINDOW is gone. Pages say whether
  # they're in use; the latest of those keeps a member active.
  PRESENCE_BEAT = 30.seconds
  PRESENCE_WINDOW = 75.seconds

  # A page checking in: always seen, and active if it's in use.
  def check_in!(active:, at: Time.current)
    update_columns(seen_at: at, active_at: (active ? at : active_at))
  end

  # "active" (green halo), "idle" (yellow: connected, not in use lately) or
  # "away" (no halo: no page open).
  def presence(now: Time.current)
    if active_at && active_at > now - PRESENCE_WINDOW then "active"
    elsif seen_at && seen_at > now - PRESENCE_WINDOW then "idle"
    else "away"
    end
  end

  # While we improve Grimwilder, each account is at one active campaign at a
  # time, GM or player. Planned: playing in any number stays free, and running
  # more than one becomes the paid plan (see Roadmap in AGENTS.md). Said the
  # same way on the campaigns page, the join page and a refused join.
  def self.one_campaign_limit(membership)
    way_out = membership.gm? ? "mark it done in its settings" : "leave it or wait for its GM to mark it done"
    "You're at #{membership.campaign.name}. While we're improving Grimwilder, each account can be in one active campaign at a time. " \
      "Later, playing in as many as you like will be free, and running more than one will be part of a paid plan. To start or join another, #{way_out}."
  end

  # The other active campaign this member is at, if any (see one_campaign_limit).
  def other_active_membership
    identity.active_membership(except: campaign_id)
  end

  # The characters this member plays here: seated, and still playing.
  def seated_characters
    identity.characters.where(campaign: campaign).played.active.ordered
  end

  # The one their tab and the live banner lead to when there's a choice: the first by name.
  def seated_character
    seated_characters.first
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

    def one_active_campaign
      if campaign&.done?
        errors.add(:base, "#{campaign.name} is done, so no one can join it.")
      elsif (other = other_active_membership)
        errors.add(:base, self.class.one_campaign_limit(other))
      end
    end
end
