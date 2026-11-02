# One date of a campaign's schedule that isn't plainly the rule's
# (Campaign::Schedule): a rule date skipped (with an optional note) or moved
# to another time, or an extra date the GM added. Rule dates themselves are
# worked out, never stored; later, RSVPs will point at a row made lazily
# with status "scheduled".
class GameDate < ApplicationRecord
  STATUSES = %w[ scheduled skipped moved extra ].freeze
  NOTE_LIMIT = 200

  belongs_to :campaign

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :note, with: -> { _1.strip.presence }

  validates :note, length: { maximum: NOTE_LIMIT }
  validates :occurs_on, presence: true, unless: :extra?
  validates :occurs_on, absence: true, if: :extra?
  validates :starts_at, presence: true, if: -> { moved? || extra? }
end
