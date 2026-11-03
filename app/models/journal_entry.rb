# A page of a player's journal (Journal): what they wrote about one session,
# or about the stretch after it (between: true; session 0 is before Session 1).
class JournalEntry < ApplicationRecord
  BODY_LIMIT = 10_000

  belongs_to :membership

  normalizes :body, with: ->(value) { value.strip }

  validates :body, presence: true, length: { maximum: BODY_LIMIT }
  validates :session_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :session_number, uniqueness: { scope: %i[ membership_id between ] }
  validate :a_session_has_a_number

  private
    def a_session_has_a_number
      errors.add(:session_number, "must be a session") if session_number.to_i.zero? && !between
    end
end
