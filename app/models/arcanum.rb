# An arcana (pg. 41–44): a relic a character holds. Its name, function and
# touchstones decide what it can do; its tier how much (minor, major, mythic,
# or trivial for an expendable one). It may have a power pool, kept in the
# character's campaign like a talent pool and refilled each session
# (Character::Arcana). Expendable arcana are used up once.
#
# One is an "arcanum" in the code so Rails can tell one from many; the book
# and the sheet say "arcana" for both.
class Arcanum < ApplicationRecord
  TIERS = %w[ trivial minor major mythic ].freeze
  POOL_SIZES = { "minor" => 2, "major" => 4, "mythic" => 6 }.freeze
  # Optional additions (pg. 42), more likely on greater arcana: key => [name, what it means].
  ADDITIONS = {
    "heavy_cost" => [ "Heavy cost", "Its magic has an upfront cost: pushing yourself, harm, vex or a temporary condition." ],
    "unique_reset" => [ "Unique reset", "Its power pool doesn't reset each session; an act, event, resource, spark or thread restores it." ],
    "ritual" => [ "Ritual ability", "Given time, or with an 8d timer pool, it can produce a ritual-level effect." ],
    "curse" => [ "Curse", "A secret drawback: costly to use, or twisting the user toward its own desires." ],
    "sentient" => [ "Sentient", "It can communicate, and has its own thoughts, goals and wises." ]
  }.freeze
  TOUCHSTONE_LIMIT = 6
  LIMITS = { "description" => 2000, "limitations" => 1000 }.freeze

  # Magnum Opus (pg. 56): a mythic arcana still being made. Before each
  # session, roll touchstones for the ones not yet locked in (3 in all), then
  # lock in 1 of them, never rolling for it again.
  OPUS = "magnum-opus"
  OPUS_TOUCHSTONES = 3

  belongs_to :character
  has_one :pool, dependent: :destroy

  enum :tier, TIERS.index_by(&:itself), default: "minor", validate: true

  normalizes :name, with: ->(value) { value.squish }
  normalizes :description, :limitations, with: ->(value) { value.strip.presence }

  validates :name, presence: true, length: { maximum: 80 }
  validates :function, inclusion: { in: ->(_) { Grimwild.arcana_functions.keys }, message: "should be one of the ten functions" }
  validates :description, length: { maximum: LIMITS["description"] }
  validates :limitations, length: { maximum: LIMITS["limitations"] }
  validate :trivial_only_when_expendable, :pool_needs_a_size, :from_a_known_talent

  after_save :refresh_pool, if: -> { saved_change_to_power_pool? || saved_change_to_tier? || saved_change_to_name? || saved_change_to_used_at? }

  scope :ordered, -> { order(:used_at, :created_at, :id) }

  def additions=(value)
    super(Array(value).map(&:to_s) & ADDITIONS.keys)
  end

  def unique_reset?
    additions.include?("unique_reset")
  end

  def touchstones=(value)
    super(Array(value.is_a?(Hash) ? value.values : value).map { _1.to_s.squish.first(Character::WORD_LIMIT) }.compact_blank.uniq(&:downcase).first(TOUCHSTONE_LIMIT))
  end

  # The function first: it's a touchstone too (pg. 43).
  def all_touchstones
    [ function, *touchstones ]
  end

  def pool_size
    POOL_SIZES[tier] if power_pool?
  end

  def used?
    used_at.present?
  end

  def use_up!
    update!(used_at: Time.current)
  end

  def restore!
    update!(used_at: nil)
  end

  # "Major expendable arcana", "Mythic arcana".
  def tier_label
    [ tier.capitalize, ("expendable" if expendable?), "arcana" ].compact.join(" ")
  end

  def granted_by
    Talent.find_by_key(source) if source
  end

  # --- Magnum Opus -------------------------------------------------------------

  def opus?
    source == OPUS
  end

  def opus_complete?
    touchstones.size >= OPUS_TOUCHSTONES
  end

  # Rolls this session's touchstones from the arcana crucibles (pg. 44): one
  # for each not yet locked in, never one it already has.
  def roll_opus_touchstones!(random: Random)
    raise ArgumentError, "#{name} isn't a Magnum Opus." unless opus?
    raise ArgumentError, "#{name} has all its touchstones." if opus_complete?

    words = Crucible.find("arcana").tables.flat_map { _1.rows.flatten }.uniq - touchstones
    update!(rolled_touchstones: words.sample(OPUS_TOUCHSTONES - touchstones.size, random: random), lock_ready: true)
  end

  # Locks one of this session's rolled touchstones in for good.
  def lock_opus_touchstone!(word)
    raise ArgumentError, "Roll before locking a touchstone in." unless lock_ready?
    raise ArgumentError, "#{word.inspect} wasn't rolled this session." unless rolled_touchstones.include?(word)

    update!(touchstones: touchstones + [ word ], rolled_touchstones: rolled_touchstones - [ word ], lock_ready: false)
  end

  private
    def trivial_only_when_expendable
      errors.add(:tier, "can be trivial only for expendable arcana") if trivial? && !expendable?
    end

    def pool_needs_a_size
      errors.add(:power_pool, "isn't for trivial arcana") if power_pool? && trivial?
    end

    def from_a_known_talent
      errors.add(:source, "isn't a talent") if source.present? && Talent.find_by_key(source).nil?
    end

    def refresh_pool
      character.refresh_arcana_pools!
    end
end
