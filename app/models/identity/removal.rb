# An admin removing an account (Admin::IdentitiesController#destroy). It can't
# while the account is the only GM of a campaign others are in: another GM
# takes over first, or its GM deletes it. A campaign the account is alone in
# goes with it; every other one it leaves as if it left itself
# (Membership#destroy: its characters leave the party, and ones up for grabs
# pass to another GM). Its characters, passkeys, sign-ins and feedback go;
# its rolls, chat, roll calls and polls stay, as a removed account's
# (OutlivesItsAccount). Whispers to it go too: with no one on that side, a
# player's whisper would read as one to the GM.
module Identity::Removal
  extend ActiveSupport::Concern

  included do
    has_many :rolls, dependent: :nullify
    has_many :messages, dependent: :nullify
    has_many :whispers_received, -> { whisper }, class_name: "Message", foreign_key: :recipient_id, dependent: :delete_all
    has_many :roll_calls, dependent: :nullify
    has_many :table_questions, dependent: :nullify
    has_many :pools_last_rolled, class_name: "Pool", foreign_key: :last_rolled_by_id, dependent: :nullify
  end

  class_methods do
    # Who a removed account's rolls and lines read as. Never saved.
    def removed
      new(name: "Removed account", email_address: "removed@grimwilder.invalid").tap(&:readonly!)
    end
  end

  # Why the account can't be removed yet, or nil.
  def removal_blocked_by
    names = memberships.gm.includes(:campaign).map(&:campaign)
      .select { _1.memberships.gm.count == 1 && _1.memberships.count > 1 }.map(&:name)
    "#{display_name} is the only GM of #{names.to_sentence}, which others are in. Another GM takes over first, or the campaign is deleted." if names.any?
  end

  def remove!
    raise ArgumentError, removal_blocked_by if removal_blocked_by

    transaction do
      memberships.includes(:campaign).each do |membership|
        if membership.campaign.memberships.where.not(id: membership.id).none? then membership.campaign.destroy!
        else membership.destroy!
        end
      end
      destroy!
    end
  end
end
