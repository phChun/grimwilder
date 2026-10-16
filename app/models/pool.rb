# A diminishing pool (Grimwild CE pg. 18–19): a set of d6s tracking progress
# toward an event. Rolling drops every die showing 1–3; at 0d the event
# happens. Mirrors rollPool in app/javascript/grimwild/dice.js.
class Pool < ApplicationRecord
  KINDS = {
    "task" => "Effort toward a goal, or defeating a foe",
    "pressure" => "A threat closing in",
    "timer" => "Events unfolding in the background",
    "resource" => "Something precious running out",
    "power" => "An ability that fades with use",
    "campaign" => "A long-term clock, rolled in downtime"
  }.freeze

  # Short labels for the type picker.
  LABELS = {
    "task" => "Task: effort or a foe",
    "pressure" => "Pressure: a threat closing in",
    "timer" => "Timer: events in the background",
    "resource" => "Resource: running out",
    "power" => "Power: fades with use",
    "campaign" => "Campaign: long-term, downtime"
  }.freeze

  OUTCOMES = {
    "task" => "Done.",
    "pressure" => "It arrives.",
    "timer" => "Time's up.",
    "resource" => "All gone.",
    "power" => "Spent.",
    "campaign" => "It comes to pass."
  }.freeze

  SIZE_PRESETS = [ 2, 4, 6, 8 ].freeze
  MAX_SIZE = 20

  belongs_to :campaign
  belongs_to :last_rolled_by, class_name: "Identity", optional: true
  has_many :rolls, dependent: :nullify

  enum :kind, KINDS.keys.index_by(&:itself), default: "task", validate: true

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 80 }
  validates :starting_size, numericality: { only_integer: true, in: 1..MAX_SIZE }
  validates :size, numericality: { only_integer: true, in: 0..MAX_SIZE }

  before_validation :start_full, on: :create

  scope :ordered, -> { order(:created_at, :id) }
  scope :visible_to, ->(membership) { membership&.gm? ? all : where(hidden: false) }

  # Everyone looking at the campaign's pools refetches the page; each viewer's
  # own request decides what they may see (hidden pools stay GM-only).
  broadcasts_refreshes_to ->(pool) { [ pool.campaign, :pools ] }

  def depleted?
    size.zero?
  end

  def rollable?
    !depleted?
  end

  # drop_first: Greater effect, potency and some talents drop 1d before rolling.
  #
  # as_action: a risky use of a power pool (pg. 19) rolls it as an action roll
  # in place of a stat. The highest die is the result, then 1–3s drop as usual.
  # Spark dice, spent by a character, count toward the result but never drop
  # or join the pool. A use that isn't risky just rolls: it works, and dice drop.
  def roll!(by:, drop_first: false, as_action: false, thorns: 0, character: nil, spend_spark: 0, random: Random)
    raise ArgumentError, "#{name} is at 0d and can't be rolled" if depleted?
    check_action_roll!(drop_first:, as_action:, thorns:, character:, spend_spark:)

    before = size
    dice = Array.new(drop_first ? size - 1 : size) { random.rand(1..6) }
    kept = dice.count { |die| die >= 4 }

    if as_action
      spark_dice = Array.new(spend_spark) { random.rand(1..6) }
      result = Grimwild::Dice.interpret(dice + spark_dice, Array.new(thorns) { random.rand(1..8) })
    end

    record!(size: kept, dice: dice, dropped: before - kept, action: drop_first ? "rolled_after_drop" : "rolled", by: by,
      result: result, spark_dice: spark_dice || [], character: character)
  end

  # A task pool roll that dropped nothing: the player takes a mark to drop 1d anyway.
  def pushable?
    task? && last_action == "rolled" && last_dropped == 0 && !depleted?
  end

  def push!(by:)
    raise ArgumentError, "#{name} can't be pushed right now" unless pushable?

    record!(size: size - 1, dice: last_dice, dropped: 1, action: "pushed", by: by)
  end

  def resettable?
    last_action.present? || size != starting_size
  end

  def reset!
    update!(size: starting_size, last_dice: [], last_dropped: nil, last_action: nil, last_rolled_by: nil, last_rolled_at: nil)
  end

  def outcome
    OUTCOMES.fetch(kind)
  end

  def description
    KINDS.fetch(kind)
  end

  private
    def start_full
      self.size ||= starting_size
    end

    def check_action_roll!(drop_first:, as_action:, thorns:, character:, spend_spark:)
      if as_action
        raise ArgumentError, "Only a power pool is rolled as an action." unless power?
        raise ArgumentError, "Thorns go from 0 to #{Character::Rolling::MAX_EXTRA}." unless thorns.in?(0..Character::Rolling::MAX_EXTRA)
        raise ArgumentError, "Only a character can spend spark." if character.nil? && spend_spark != 0
        raise ArgumentError, "#{character&.name} isn't seated in #{campaign.name}." if character && character.campaign_id != campaign_id
        character&.check_spark_spend!(spend_spark)
        raise ArgumentError, "Dropping 1d first leaves nothing to roll." if drop_first && size == 1 && spend_spark.zero?
      elsif thorns != 0 || spend_spark != 0 || character
        raise ArgumentError, "Thorns and spark only go into a roll as an action."
      end
    end

    # Every roll, drop and push also goes in the campaign's log. A push rolls
    # nothing, so its entry has no dice. An action roll's entry keeps its spark
    # dice after the pool's own, and its result.
    def record!(size:, dice:, dropped:, action:, by:, result: nil, spark_dice: [], character: nil)
      transaction do
        gained = character&.settle_spark(spent: spark_dice.size, take: result&.result == "disaster") || false
        character&.save!

        update!(size: size, last_dice: dice, last_dropped: dropped, last_action: action, last_rolled_by: by, last_rolled_at: Time.current)
        rolls.create!(campaign: campaign, identity: by, kind: "pool", name: name, dice: (action == "pushed" ? [] : dice + spark_dice),
          pool_action: action, dropped: dropped, remaining: size, gm_only: hidden?,
          thorns: result&.thorns || [], outcome: result&.result, critical: result&.critical || false,
          character: character, spark_spent: spark_dice.size, spark_gained: gained)
      end
    end
end
