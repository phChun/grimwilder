# A page of a player's journal (Journal), with an optional title. The player
# writes most and stars the ones they want on top (favorite). A GM may add one
# (by_gm), say for a secret or a backstory, and lock it so the player can read
# it but not change it; unlocked, both write in it, like Character Secrets,
# which every player starts with.
class JournalPage < ApplicationRecord
  BODY_LIMIT = 10_000
  TITLE_LIMIT = 100
  SECRETS = "Character Secrets"

  belongs_to :membership

  # How the journal lists them (Journal::SORTS): starred then newest, in the
  # order written, or the latest changed first.
  scope :favorites_first, -> { order(favorite: :desc, created_at: :desc, id: :desc) }
  scope :chronologically, -> { order(:created_at, :id) }
  scope :last_updated, -> { order(updated_at: :desc, id: :desc) }
  scope :by_gm, -> { where(by_gm: true) }

  normalizes :title, with: ->(value) { value.strip.presence }
  normalizes :body, with: ->(value) { value.strip }

  validates :title, length: { maximum: TITLE_LIMIT }
  validates :body, length: { maximum: BODY_LIMIT }
  validate :has_a_title_or_words

  before_save { self.locked = false unless by_gm }

  # Every player's first page: Character Secrets, for the GM and the player both.
  def self.start_for!(membership)
    membership.journal_pages.create!(title: SECRETS, by_gm: true, favorite: true)
  end

  # Its title, or the day it was started for an untitled one.
  def heading
    title || created_at&.strftime("%B %-d, %Y") || "New page"
  end

  # Written by the GM, and open for the player to write in too.
  def shared?
    by_gm? && !locked?
  end

  private
    def has_a_title_or_words
      errors.add(:base, "Give it a title or write something") if title.blank? && body.blank?
    end
end
