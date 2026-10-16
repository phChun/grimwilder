# Action and defense rolls from the sheet (pg. 10–15). The server rolls, so
# the table's log can be trusted, and everything a roll changes on the sheet
# happens with it:
#
# - each spark spent before the roll adds 1d (pg. 12);
# - damage adds its thorns, and a mark on the stat clears once rolled (pg. 27);
# - a disaster gives spark, up to the 2 a character can hold (pg. 10, 15).
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
    raise ArgumentError, "#{name} can spend 0–#{spark} spark." unless spend_spark.in?(0..spark)
    raise ArgumentError, "Help dice and thorns go from 0 to #{MAX_EXTRA}." unless [ help, thorns ].all? { _1.in?(0..MAX_EXTRA) }

    reasons = damage_reasons(stat_name)
    result = Grimwild::Dice.roll(stat(stat_name) + spend_spark + help, reasons.size + thorns, random: random)

    transaction do
      self.spark -= spend_spark
      gained = result.result == "disaster" && spark < Grimwild::MAX_SPARK
      self.spark += 1 if gained
      self[:"marked_#{stat_name}"] = false
      save!

      rolls.create!(
        campaign: campaign, identity: by, kind: mode, name: name, stat: stat_name,
        dice: result.dice, thorns: result.thorns, outcome: result.result, critical: result.critical,
        stat_dice: stat(stat_name), help_dice: help, spark_spent: spend_spark, damage_reasons: reasons, spark_gained: gained
      )
    end
  end
end
