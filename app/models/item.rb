# An important item a character carries that isn't arcana: a map, a key, a
# letter, a family sword. A name, what matters about it and, if it's
# counted (Countable), how many; shown with the arcana.
class Item < ApplicationRecord
  include Countable

  DESCRIPTION_LIMIT = 1000

  belongs_to :character

  normalizes :name, with: ->(value) { value.squish }
  normalizes :description, with: ->(value) { value.strip.presence }

  validates :name, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: DESCRIPTION_LIMIT }

  scope :ordered, -> { order(:created_at, :id) }
end
