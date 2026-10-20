# A line of table chat: out-of-game talk, kept apart from the roll log so it
# never buries the rolls. Anyone at the table can speak as themselves or as one
# of their own seated characters. The speaker's name is copied in, so the chat
# still reads right after a rename or delete.
class Message < ApplicationRecord
  MAX_LENGTH = 500
  CHAT_SIZE = 40

  belongs_to :campaign
  belongs_to :identity
  belongs_to :character, optional: true

  validates :name, presence: true
  validates :body, presence: true, length: { maximum: MAX_LENGTH }
  validate :speaks_as_own_seated_character, if: :character

  normalizes :body, with: ->(body) { body.strip }

  before_validation { self.name = character&.name || identity&.display_name }

  # Everyone at the table follows one chat stream. The partial renders here,
  # outside a request, so it must not use Current.
  after_create_commit -> { broadcast_append_to [ campaign, :chat ], target: "chat_messages", partial: "messages/message", locals: { message: self } }

  # The newest messages, oldest first, the way a chat reads.
  def self.chat_for(campaign, limit: CHAT_SIZE)
    where(campaign: campaign).includes(:identity).order(created_at: :desc, id: :desc).limit(limit).reverse
  end

  private
    def speaks_as_own_seated_character
      errors.add(:character, "must be one of your characters at this table") unless character.identity_id == identity_id && character.campaign_id == campaign_id
    end
end
