# The GM's two ways to send a player away: removing them (Membership#destroy;
# the invite link lets them back) or blocking them, which removes them and
# keeps them out until the block is lifted.
module Campaign::Blocking
  extend ActiveSupport::Concern

  included do
    has_many :blocks, dependent: :delete_all
  end

  def block!(membership, by:)
    raise ArgumentError, "Only players can be blocked." unless membership.player? && membership.campaign_id == id

    transaction do
      blocks.find_or_create_by!(identity: membership.identity) { _1.blocked_by = by }
      membership.destroy!
    end
  end

  def blocked?(identity)
    identity.present? && blocks.exists?(identity: identity)
  end
end
