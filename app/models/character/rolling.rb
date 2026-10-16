# Action and defense rolls from the sheet (pg. 10–15). The server rolls, so
# the table's log can be trusted, and everything a roll changes on the sheet
# happens with it:
#
# - each spark spent before the roll adds 1d (pg. 12);
# - damage adds its thorns, and a mark on the stat clears once rolled (pg. 27);
# - a disaster gives spark, up to the 2 a character can hold (pg. 10, 15);
# - so does a critical when none of its effects fit (pg. 10), if the player
#   takes it right away: only on the character's latest roll.
module Character::Rolling
  extend ActiveSupport::Concern

  MODES = %w[ action defense ].freeze
  MAX_EXTRA = 4 # help dice or situational thorns; typical play is 0–2

  included do
    has_many :rolls, dependent: :nullify
  end

  # help: extra dice from assists and talents. thorns: situational thorns,
  # on top of the ones damage adds.
  def roll!(stat_name, by:, mode: "action", spend_spark: 0, help: 0, thorns: 0, random: Random)
    stat_name = stat_name.to_s
    raise ArgumentError, "Pick Brawn, Agility, Wits or Presence." unless Grimwild::STATS.include?(stat_name)
    raise ArgumentError, "Pick an action or a defense roll." unless MODES.include?(mode)
    check_spark_spend!(spend_spark)
    raise ArgumentError, "Help dice and thorns go from 0 to #{MAX_EXTRA}." unless [ help, thorns ].all? { _1.in?(0..MAX_EXTRA) }

    reasons = damage_reasons(stat_name)
    result = Grimwild::Dice.roll(stat(stat_name) + spend_spark + help, reasons.size + thorns, random: random)

    transaction do
      gained = settle_spark(spent: spend_spark, take: result.result == "disaster")
      self[:"marked_#{stat_name}"] = false
      save!

      rolls.create!(
        campaign: campaign, identity: by, kind: mode, name: name, stat: stat_name,
        dice: result.dice, thorns: result.thorns, outcome: result.result, critical: result.critical,
        stat_dice: stat(stat_name), help_dice: help, spark_spent: spend_spark, damage_reasons: reasons, spark_gained: gained
      )
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
