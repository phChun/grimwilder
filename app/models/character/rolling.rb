# Action and defense rolls from the sheet (pg. 10–15). The server rolls, so
# the table's log can be trusted, and everything a roll changes on the sheet
# happens with it:
#
# - each spark spent before the roll adds 1d (pg. 12);
# - each ally assisting rolls 1d of their own, which counts toward the result
#   and is shown separately (pg. 13);
# - damage adds its thorns, and a mark on the stat clears once rolled (pg. 27);
# - a disaster gives spark, up to the 2 a character can hold (pg. 10, 15);
# - so does a critical when none of its effects fit (pg. 10), if the player
#   takes it right away: only on the character's latest roll.
module Character::Rolling
  extend ActiveSupport::Concern

  MODES = %w[ action defense ].freeze
  MAX_EXTRA = 4 # extra dice or situational thorns; typical play is 0–2

  included do
    has_many :rolls, dependent: :nullify
  end

  # help: extra dice from talents and outside help (an NPC, the scene).
  # assists: other characters seated alongside this one, each rolling 1d.
  # thorns: situational thorns, on top of the ones damage adds.
  def roll!(stat_name, by:, mode: "action", spend_spark: 0, help: 0, assists: [], thorns: 0, random: Random)
    stat_name = stat_name.to_s
    raise ArgumentError, "#{name} is #{status}; return them to play to roll." if gone?
    raise ArgumentError, "Pick Brawn, Agility, Wits or Presence." unless Grimwild::STATS.include?(stat_name)
    raise ArgumentError, "Pick an action or a defense roll." unless MODES.include?(mode)
    check_spark_spend!(spend_spark)
    raise ArgumentError, "Extra dice and thorns go from 0 to #{MAX_EXTRA}." unless [ help, thorns ].all? { _1.in?(0..MAX_EXTRA) }
    check_assists!(assists)

    reasons = damage_reasons(stat_name)
    own = Grimwild::Dice.roll(stat(stat_name) + spend_spark + help, reasons.size + thorns, random: random)
    assist_dice = assists.map { random.rand(1..6) }
    result = Grimwild::Dice.interpret(own.dice + assist_dice, own.thorns)

    transaction do
      gained = settle_spark(spent: spend_spark, take: result.result == "disaster")
      self.changed_by = by
      self[:"marked_#{stat_name}"] = false
      save!

      rolls.create!(
        campaign: campaign, identity: by, kind: mode, name: name, stat: stat_name,
        dice: own.dice, thorns: own.thorns, outcome: result.result, critical: result.critical,
        stat_dice: stat(stat_name), help_dice: help, spark_spent: spend_spark, damage_reasons: reasons, spark_gained: gained,
        assists: assists.zip(assist_dice).map { |ally, die| { "character_id" => ally.id, "name" => ally.name, "die" => die } }
      )
    end
  end

  def check_assists!(allies)
    unless allies.uniq.size == allies.size && allies.none?(self) && allies.all? { campaign_id && _1.campaign_id == campaign_id && _1.active? }
      raise ArgumentError, "Only other characters seated in #{campaign&.name || "a campaign"} with #{name} can assist."
    end
  end

  def check_spark_spend!(amount)
    raise ArgumentError, "#{name} can spend 0–#{spark} spark." unless amount.in?(0..spark)
  end

  # Spark spent before a roll (+1d each), then spark taken after it (from a
  # disaster, a quarrel...), up to the 2 a character can hold (pg. 12). Doesn't
  # save. Returns whether spark was taken.
  def settle_spark(spent: 0, take: false)
    self.spark -= spent
    (take && spark < Grimwild::MAX_SPARK).tap { |taken| self.spark += 1 if taken }
  end

  def can_take_spark_for?(roll)
    (roll.action? || roll.defense?) && roll.critical? && !roll.spark_gained? && spark < Grimwild::MAX_SPARK && rolls.recent.first == roll
  end

  def take_spark_for_critical!(roll)
    raise ArgumentError, "Spark from a critical is for #{name}'s latest critical, once, below #{Grimwild::MAX_SPARK} spark." unless can_take_spark_for?(roll)

    transaction do
      increment!(:spark)
      roll.update!(spark_gained: true)
    end
  end
end
