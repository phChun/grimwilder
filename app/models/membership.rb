# An identity's seat at a campaign: the GM who runs it, or a player.
class Membership < ApplicationRecord
  belongs_to :campaign
  belongs_to :identity

  enum :role, { gm: "gm", player: "player" }, default: :player, validate: true

  validates :identity_id, uniqueness: { scope: :campaign_id }
  validate :within_plan, :not_blocked, on: :create

  before_destroy :ensure_campaign_keeps_a_gm
  after_destroy :unseat_characters
  after_destroy_commit :send_open_pages_away

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

  # The characters this member plays here: seated, and still playing.
  def seated_characters
    identity.characters.where(campaign: campaign).played.active.ordered
  end

  # Whose talents they can bring to someone's roll after it's made
  # (Roll::FollowUps): their own characters here, or for the GM everyone's,
  # as the GM tends any character at the table.
  def follow_up_characters
    gm? ? campaign.characters.played.active.ordered : seated_characters
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

    # A player removed or blocked may still have the campaign open: refresh
    # their pages (the rail follows [membership, :chat]), which now 404.
    def send_open_pages_away
      Turbo::StreamsChannel.broadcast_refresh_to(self, :chat) if player? && !destroyed_by_association
    end

    def not_blocked
      errors.add(:base, "The GM has blocked you from #{campaign.name}.") if campaign&.blocked?(identity)
    end

    def ensure_campaign_keeps_a_gm
      if gm? && !destroyed_by_association && campaign.memberships.gm.where.not(id: id).none?
        errors.add(:base, "A campaign needs at least one GM")
        throw :abort
      end
    end

    # Each account runs and plays in as many active campaigns as its plan
    # allows (Identity::Plans).
    def within_plan
      if campaign&.archived?
        errors.add(:base, "#{campaign.name} is archived, so no one can join it.")
      elsif identity && !identity.room_for?(role, except: campaign_id)
        errors.add(:base, identity.plan_limit_message(role))
      end
    end
end
