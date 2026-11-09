# A page of a player's journal (Journal), with an optional title. The player
# writes most; a GM may add one (by_gm), say for a secret or a backstory, and
# lock it so the player can read it but not change it.
class JournalPage < ApplicationRecord
  BODY_LIMIT = 10_000
  TITLE_LIMIT = 100

  belongs_to :membership

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :by_gm, -> { where(by_gm: true) }

  normalizes :title, with: ->(value) { value.strip.presence }
  normalizes :body, with: ->(value) { value.strip }

  validates :title, length: { maximum: TITLE_LIMIT }
  validates :body, presence: true, length: { maximum: BODY_LIMIT }

  before_save { self.locked = false unless by_gm }

  # Its title, or the day it was started for an untitled page.
  def heading
    title || created_at&.to_date&.to_fs(:long) || "New page"
  end
end
