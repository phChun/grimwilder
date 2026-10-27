# A diminishing pool (Grimwild CE pg. 19–20): a set of d6s tracking progress
# toward an event. Rolling drops every die showing 1–3; at 0d the event
# happens. Mirrors rollPool in app/javascript/grimwild/dice.js.
class Pool < ApplicationRecord
  include Phases

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
  belongs_to :character, optional: true # a talent pool (Character::TalentUses)
  belongs_to :arcanum, optional: true # an arcana's power pool (Character::Arcana)
  has_many :rolls, dependent: :nullify

  enum :kind, KINDS.keys.index_by(&:itself), default: "task", validate: true

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 80 }
  validates :starting_size, numericality: { only_integer: true, in: 1..MAX_SIZE }
  validates :size, numericality: { only_integer: true, in: 0..MAX_SIZE }

  before_validation :start_full, on: :create

  scope :ordered, -> { order(:created_at, :id) }
  scope :shared, -> { where(character_id: nil) }
  scope :talent, -> { where.not(character_id: nil) }
  scope :visible_to, ->(membership) { membership&.gm? ? all : where(hidden: false) }

  # Everyone looking at the campaign's pools refetches the page; each viewer's
  # own request decides what they may see (hidden pools stay GM-only).
  broadcasts_refreshes_to ->(pool) { [ pool.campaign, :pools ] }

  def depleted?
    size.zero?
  end

  def rollable?
    !depleted? && !held_by_gone_character? && !campaign.done?
  end

  # A talent pool whose character has fallen or retired waits for them to return.
  def held_by_gone_character?
    character_id.present? && character.gone?
  end

  # drop_first: Greater effect, potency and some talents drop 1d before rolling.
  #
  # as_action: a risky use of a power pool (pg. 20) rolls it as an action roll
  # in place of a stat. The highest die is the result, then 1–3s drop as usual.
  # Spark dice, spent by a character, count toward the result but never drop
  # or join the pool. A use that isn't risky just rolls: it works, and dice drop.
  def roll!(by:, drop_first: false, as_action: false, thorns: 0, character: nil, spend_spark: 0, random: Random)
    raise ArgumentError, "#{name} is at 0d and can't be rolled" if depleted?
    return tick!(by: by) if tick?
    raise ArgumentError, "#{self.character.name} is #{self.character.status}; return them to play to roll." if held_by_gone_character?
    raise ArgumentError, "#{campaign.name} is done." if campaign.done?
    check_action_roll!(drop_first:, as_action:, thorns:, character:, spend_spark:)

    before = size
    dice = Array.new(drop_first ? size - 1 : size) { random.rand(1..6) }
    kept = dice.count { |die| die >= 4 }
    kept += 1 if archivist_keeps_one?(before, dice)

    if as_action
      spark_dice = Array.new(spend_spark) { random.rand(1..6) }
      result = Grimwild::Dice.interpret(dice + spark_dice, Array.new(thorns) { random.rand(1..8) })
    end

    record!(size: kept, dice: dice, dropped: before - kept, action: drop_first ? "rolled_after_drop" : "rolled", by: by,
      result: result, spark_dice: spark_dice || [], character: character)
  end

  # A talent pool rolled into someone's roll after it's made (Roll::FollowUps:
  # Luck's bonus die, Component Pouch's reagents). 1–3s drop as usual, but the
  # log shows it on that roll, so this adds no entry of its own.
  def roll_into!(by:, random: Random)
    raise ArgumentError, "#{name} is at 0d and can't be rolled" if depleted?
    raise ArgumentError, "#{character.name} is #{character.status}; return them to play to roll." if held_by_gone_character?
    raise ArgumentError, "#{campaign.name} is done." if campaign.done?

    dice = Array.new(size) { random.rand(1..6) }
    kept = dice.count { |die| die >= 4 }
    update!(size: kept, last_dice: dice, last_dropped: size - kept, last_action: "rolled", last_rolled_by: by, last_rolled_at: Time.current,
      **next_phase_attributes(kept).to_h, **refill_attributes(kept.zero? && refills_left?))
    dice
  end

  # Who may drop 1d before rolling (pg. 11, 19–20, 97): anyone on a task pool,
  # for a critical's Greater effect; the GM on any shared pool, with suspense;
  # on a talent pool only when the talent says so (a potent rite spell); and
  # on a mythic arcana's, for a potent effect (pg. 42).
  def drops_first_for?(gm:)
    if tick? then false
    elsif arcanum
      arcanum.mythic?
    elsif character_id
      talent_use&.drop_first || false
    else
      task? || gm
    end
  end

  # Archivist (pg. 88): when you roll an arcana's power pool, you drop 1 fewer
  # die, unless it's the last.
  def archivist_keeps_one?(before, dice)
    arcanum_id.present? && character.present? && before > 1 && dice.any? { _1 <= 3 } &&
      [ *character.talent_entries, *character.eldritch_talent_entries ].any? { _1.key == "archivist" }
  end

  # A power pool rolled as an action in place of a stat (pg. 20). A talent's
  # bonus-dice pool (Luck) just rolls.
  def rolls_as_action?
    power? && !tick? && !talent_use&.bonus_dice
  end

  # The Talent::Use (or Talent::MadePool) a talent pool comes from.
  def talent_use
    return character&.rule_uses&.find { _1.id == use_key } if use_key.to_s.start_with?("rule/")

    talent = Talent.find_by_key(use_key.to_s.split("/").first)
    talent && (made_by_talent? ? talent.makes : talent.uses).find { _1.id == use_key }
  end

  # A task pool roll that dropped nothing: the player takes a mark to drop 1d anyway.
  def pushable?
    task? && last_action == "rolled" && last_dropped == 0 && !depleted? && !held_by_gone_character? && !campaign.done?
  end

  def push!(by:)
    raise ArgumentError, "#{name} can't be pushed right now" unless pushable?

    record!(size: size - 1, dice: last_dice, dropped: 1, action: "pushed", by: by)
  end

  # A tick pool (optional rule, pg. 178) is never rolled: each time it's
  # triggered, exactly 1d drops.
  def tick!(by:)
    raise ArgumentError, "#{name} is at 0d" if depleted?
    raise ArgumentError, "#{campaign.name} is done." if campaign.done?

    record!(size: size - 1, dice: [], dropped: 1, action: "ticked", by: by)
  end

  # Oathsworn's smite (pg. 69): after a task pool is rolled, spend smite 1-for-1
  # to drop its dice.
  SMITE = "oathsworn/smite"

  def smitable?
    task? && !hidden? && rollable? && last_action.in?(%w[ rolled rolled_after_drop smite ])
  end

  def smite!(character:, by:)
    use = character.use_counters.find { _1.id == SMITE }
    raise ArgumentError, "Only a task pool that's just been rolled can be smitten." unless smitable?
    raise ArgumentError, "#{character.short_name} has no smite left." unless use && character.in_play? && character.campaign_id == campaign_id && character.uses_left(use).positive?

    transaction do
      character.update!(talent_uses: character.talent_uses.merge(use.id => character.uses_spent(use) + 1))
      record!(size: size - 1, dice: last_dice, dropped: 1, action: "smite", by: by, character: character)
    end
  end

  # A talent pool that comes back at 0d (Talent::Use#refill): Pact's Patience
  # every time (the patron visits), the Vassal once before it resets.
  def refills_left?
    (refills = talent_use&.refills) ? refills_used < refills : false
  end

  def resettable?
    last_action.present? || size != starting_size || phase.positive?
  end

  def reset!
    update!(**first_phase_attributes, refills_used: 0, last_dice: [], last_dropped: nil, last_action: nil, last_rolled_by: nil, last_rolled_at: nil)
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
        raise ArgumentError, "#{name} is rolled as bonus dice, not as an action." unless rolls_as_action?
        raise ArgumentError, "Thorns go from 0 to #{Character::Rolling::MAX_EXTRA}." unless thorns.in?(0..Character::Rolling::MAX_EXTRA)
        raise ArgumentError, "Only a character can spend spark." if character.nil? && spend_spark != 0
        raise ArgumentError, "#{character&.name} isn't seated in #{campaign.name}." if character && character.campaign_id != campaign_id
        raise ArgumentError, "#{character.name} is #{character.status}; return them to play to roll." if character&.gone?
        character&.check_spark_spend!(spend_spark)
        raise ArgumentError, "Dropping 1d first leaves nothing to roll." if drop_first && size == 1 && spend_spark.zero?
      elsif thorns != 0 || spend_spark != 0 || character
        raise ArgumentError, "Thorns and spark only go into a roll as an action."
      end
    end

    # Every roll, drop and push also goes in the campaign's log. A push rolls
    # nothing, so its entry has no dice. An action roll's entry keeps its spark
    # dice after the pool's own, and its result. A linked pool's entry names the
    # phase rolled, and the next one if this roll unlocked it.
    def refill_attributes(refilled)
      refilled ? { size: starting_size, refills_used: refills_used + 1 } : {}
    end

    def record!(size:, dice:, dropped:, action:, by:, result: nil, spark_dice: [], character: nil)
      rolled_phase, unlocked = phase_name, (next_phase if size.zero?)
      refilled = size.zero? && refills_left?

      transaction do
        gained = character&.settle_spark(spent: spark_dice.size, take: result&.result == "disaster") || false
        character&.save!

        update!(size: size, last_dice: dice, last_dropped: dropped, last_action: action, last_rolled_by: by, last_rolled_at: Time.current,
          **next_phase_attributes(size).to_h, **refill_attributes(refilled))
        rolls.create!(campaign: campaign, identity: by, kind: "pool", name: name, dice: (action == "pushed" ? [] : dice + spark_dice),
          pool_action: action, dropped: dropped, remaining: size, gm_only: hidden?,
          phase: rolled_phase, next_phase: (unlocked && "#{unlocked["size"]}d #{unlocked["name"]}"),
          thorns: result&.thorns || [], outcome: result&.result, critical: result&.critical || false,
          character: character, spark_spent: spark_dice.size, spark_gained: gained, refilled: refilled)
      end
    end
end
