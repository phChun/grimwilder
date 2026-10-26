# Action and defense rolls from the sheet (pg. 10–15). The server rolls, so
# the table's log can be trusted, and everything a roll changes on the sheet
# happens with it:
#
# - each spark spent before the roll adds 1d (pg. 12);
# - each ally assisting rolls 1d of their own, which counts toward the result
#   and is shown separately (pg. 13);
# - damage adds its thorns, and a mark on the stat clears once rolled (pg. 27);
# - talents add dice when the situation fits, or leave thorns out
#   (Character::TalentBonuses), and any use they tick is spent;
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

  # help: extra dice from outside help (an NPC, the scene) or anything else;
  # help_from: who or what they're from, for the log.
  # assists: other characters seated alongside this one, each rolling 1d.
  # thorns: situational thorns, on top of the ones damage adds.
  # bonuses: the talent bonuses ticked (Talent::Bonus#id); automatic ones apply anyway.
  # assist_bonuses: { ally id => bonus ids } ticked for an assist (Shepherd).
  # panache: Panache spent to remove thorns; removing them all rolls them as
  # panache dice instead (pg. 81).
  def roll!(stat_name, by:, mode: "action", spend_spark: 0, help: 0, assists: [], thorns: 0, bonuses: [], assist_bonuses: {}, panache: 0, help_from: nil, random: Random)
    stat_name = stat_name.to_s
    raise ArgumentError, "#{name} is #{status}; return them to play to roll." if gone?
    raise ArgumentError, "#{campaign.name} is done." if campaign&.done?
    raise ArgumentError, "Pick Brawn, Agility, Wits or Presence." unless Grimwild::STATS.include?(stat_name)
    raise ArgumentError, "Pick an action or a defense roll." unless MODES.include?(mode)
    check_spark_spend!(spend_spark)
    raise ArgumentError, "Extra dice and thorns go from 0 to #{MAX_EXTRA}." unless [ help, thorns ].all? { _1.in?(0..MAX_EXTRA) }
    check_assists!(assists)
    check_panache!(panache)
    talent_rolled = talent_bonuses_rolled(stat_name, mode, bonuses)
    helping = assists.map { |ally| [ ally, ally.assist_bonuses_rolled(mode, assist_bonuses.to_h.transform_keys(&:to_s)[ally.id.to_s]) ] }

    reasons = damage_reasons(stat_name)
    ignored = { "damage" => (reasons & Character::Damage::MARK_AND_HARMS).size, "situational" => thorns }
    reasons -= Character::Damage::MARK_AND_HARMS if talent_rolled.any? { _2.ignore == "damage" } # Frenzy: not a Flesh Wound
    thorns = 0 if talent_rolled.any? { _2.ignore == "situational" }
    reasons, thorns, removed = remove_thorns_with_panache(panache, reasons, thorns)
    reasons += talent_rolled.flat_map { Array.new(bonus_thorns(_2), "instability") }
    talent_dice = talent_rolled.sum(&:last)

    own = Grimwild::Dice.roll(stat(stat_name) + spend_spark + help + talent_dice, reasons.size + thorns, random: random)
    roll = rolls.build(
      campaign: campaign, identity: by, kind: mode, name: name, stat: stat_name, dice: own.dice, thorns: own.thorns,
      boosts: Array.new(removed.positive? && reasons.empty? && thorns.zero? ? removed : 0) { random.rand(1..8) },
      stat_dice: stat(stat_name), help_dice: help, help_from: (help_from.to_s.squish.first(60).presence if help.positive?), spark_spent: spend_spark, damage_reasons: reasons,
      talent_bonuses: bonus_records(talent_rolled, ignored: ignored) + panache_records(removed),
      assists: helping.flat_map { |ally, rolled| ally.assist_entries(rolled, random: random) }
    )
    result = roll.interpretation
    roll.outcome, roll.critical = result.result, result.critical

    transaction do
      roll.spark_gained = settle_spark(spent: spend_spark, take: result.result == "disaster")
      self.changed_by = by
      self[:"marked_#{stat_name}"] = false
      talent_rolled.filter_map { bonus_use(_2) }.each { |use| self.talent_uses = talent_uses.merge(use.id => uses_spent(use) + 1) }
      settle_panache(spent: removed, cut: result.applied_cuts.positive?)
      settle_assist_spark(roll, helping)
      save!
      roll.save!
      roll
    end
  end

  def check_panache!(amount)
    left = panache_use ? uses_left(panache_use) : 0
    raise ArgumentError, "#{name} can spend 0–#{left} panache." unless amount.to_i.in?(0..left)
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

  # Panache (pg. 81): spend it before a roll to remove that many thorns,
  # situational ones first. Returns the thorns left and how many it removed.
  PANACHE = "panache/panache"

  def panache_use
    use_counters.find { _1.id == PANACHE }
  end

  def can_take_spark_for?(roll)
    (roll.action? || roll.defense?) && roll.critical? && !roll.spark_gained? && spark < Grimwild::MAX_SPARK && rolls.recent.first == roll
  end

  def remove_thorns_with_panache(panache, reasons, thorns)
    removed = [ panache.to_i, reasons.size + thorns ].min
    from_situational = [ removed, thorns ].min
    [ reasons.first(reasons.size - (removed - from_situational)), thorns - from_situational, removed ]
  end

  def panache_records(removed)
    removed.positive? ? [ { "id" => PANACHE, "name" => talent_entry("panache").name, "dice" => 0, "ignored" => removed } ] : []
  end

  # Spent panache is ticked; a roll cut by a thorn gives 1 back, past the
  # most it can hold (so the spent count can go below 0).
  def settle_panache(spent:, cut:)
    return unless panache_use

    self.talent_uses = talent_uses.merge(PANACHE => uses_spent(panache_use) + spent - (cut ? 1 : 0))
  end

  # Shepherd: on a perfect, the roller and the assist both take spark.
  def settle_assist_spark(roll, helping)
    return unless roll.outcome == "perfect"

    helping.each do |ally, rolled|
      next unless rolled.any? { _2.spark == "perfect_both" }

      settle_spark(take: true)
      ally.save! if ally.settle_spark(take: true)
    end
  end

  def take_spark_for_critical!(roll)
    raise ArgumentError, "Spark from a critical is for #{name}'s latest critical, once, below #{Grimwild::MAX_SPARK} spark." unless can_take_spark_for?(roll)

    transaction do
      increment!(:spark)
      roll.update!(spark_gained: true)
    end
  end
end
