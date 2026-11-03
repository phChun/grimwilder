# A player's answer to a TableQuestion: a choice, words, or both. Made empty
# when the question is asked; answered_at says whether they have. Only the
# GMs and the player who wrote it ever see it.
class TableAnswer < ApplicationRecord
  belongs_to :table_question
  belongs_to :membership

  normalizes :body, with: ->(body) { body.strip.presence }
  normalizes :choice, with: ->(choice) { choice.squish.presence }

  validates :body, length: { maximum: TableQuestion::MAX_LENGTH }

  after_update_commit -> { table_question.broadcast_card }

  def answered?
    answered_at.present?
  end

  def characters
    membership.seated_characters
  end

  def answer!(choice: nil, body: nil)
    question = table_question
    errors.clear
    self.choice, self.body = choice, body

    if !question.open?
      errors.add(:base, "The GM has closed that question")
    elsif self.choice && !self.choice.in?(question.choices)
      errors.add(:choice, "isn't one of the GM's choices")
    elsif self.choice.nil? && self.body.nil?
      errors.add(:base, question.choices.any? ? "Pick one, or write an answer" : "Write an answer")
    end
    raise ActiveRecord::RecordInvalid, self if errors.any?

    update!(answered_at: Time.current)
  end
end
