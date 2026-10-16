# A PC's best moment from the previous session, shared at the start of this
# one (pg. 31). Players write their own characters'; the GM can write any.
class PlaySession::Moment < ApplicationRecord
  belongs_to :play_session
  belongs_to :character
  belongs_to :identity

  normalizes :text, with: ->(value) { value.strip }

  validates :text, presence: true, length: { maximum: 500 }
  validates :character_id, uniqueness: { scope: :play_session_id, message: "already has a best moment for this session" }
  validate :character_in_campaign

  def self.writable_by?(identity, character, campaign)
    character.owned_by?(identity) || identity.membership_in(campaign)&.gm?
  end

  private
    def character_in_campaign
      errors.add(:character, "isn't seated in this campaign") if character && play_session && character.campaign_id != play_session.campaign_id
    end
end
