# Someone the GM has blocked from a campaign: removed, and kept out. The
# invite link won't let them back in (Membership#not_blocked) until a GM lifts
# the block from settings.
class Campaign::Block < ApplicationRecord
  belongs_to :campaign
  belongs_to :identity
  belongs_to :blocked_by, class_name: "Identity", optional: true

  validates :identity_id, uniqueness: { scope: :campaign_id }
end
