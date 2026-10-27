# What a player does with a talent from its card: roll what it calls for
# (Talent::Roll, as a roll call for the character), and push yourself (pg.
# 21): use the talent, then mark a stat of your choice.
module Character::TalentActions
  extend ActiveSupport::Concern

  # Spends the roll's thread or talent use, then calls the roll. Anything that
  # stops the call (another one waiting, say) gives them back.
  def call_talent_roll!(key, index, by:)
    talent = talent_entry(key)
    roll = talent.rolls[index.to_i] or raise ArgumentError, "#{talent.name} has no roll like that."
    raise ArgumentError, "Seat #{name} in a campaign to roll at the table." unless campaign && !up_for_grabs?
    raise ArgumentError, "#{name} is #{status}; return them to play to roll." if gone?

    return roll_for_talent!(talent, roll, by: by) if roll.action?

    transaction do
      thorns = roll.rising ? use_counters.find { _1.id == roll.use_id }.then { uses_spent(_1) }.clamp(0, Character::Rolling::MAX_EXTRA) : 0
      spend_for_roll!(roll)
      question = "#{talent.name}: #{roll.label}"
      if roll.montage?
        RollCall.montage!(campaign: campaign, by: by, characters: [ self ], scene: question, bonus: roll.bonus)
      else
        RollCall.story!(campaign: campaign, by: by, character: self, question: question, odds: roll.odds, thorns: thorns)
      end
    end
  end

  # A pool a talent makes when used (Talent::MadePool): at a table, in play,
  # with room for another and a use left to tick.
  def can_make_pool?(made)
    use = use_counters.find { _1.id == made.use_id }
    campaign.present? && !up_for_grabs? && in_play? && talent_pools.where(use_key: made.id).count < made.at_once &&
      (!made.use || (use && uses_left(use).positive?))
  end

  def make_talent_pool!(key, made_key, by:, name: nil)
    talent = talent_entry(key)
    made = talent.makes.find { _1.key == made_key.to_s } or raise ArgumentError, "#{talent.name} makes no pool like that."
    raise ArgumentError, "#{short_name} can't make another #{made.label.downcase} now." unless can_make_pool?(made)

    called = name.to_s.squish.first(40).presence
    transaction do
      if (use = use_counters.find { _1.id == made.use_id })
        update!(talent_uses: talent_uses.merge(use.id => uses_spent(use) + 1))
      end
      pool = talent_pools.create!(campaign: campaign, use_key: made.id, made_by_talent: true, kind: made.kind, refresh: made.lasts,
        name: "#{self.name}: #{made.label}#{" (#{called})" if called}", starting_size: made.pool, size: made.pool)
      Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} makes #{pool.name.delete_prefix("#{self.name}: ")}, a #{made.pool}d #{made.kind} pool (#{talent.name}).")
      pool
    end
  end

  # Marks the stat (or the harm it turns into), and says so in the log.
  def push!(stat, talent_key:, by:)
    talent = talent_entry(talent_key)
    raise ArgumentError, "#{talent.name} doesn't ask you to push yourself." unless talent.pushes?
    raise ArgumentError, "#{name} is #{status}; return them to play to push." if gone?
    raise ArgumentError, "#{campaign.name} is done." if campaign&.done?

    self.changed_by = by
    took = take_mark(stat)
    save!
    # The Vassal's pool returns to its max when you push yourself (pg. 79).
    refilled = talent_pools.where(use_key: talent.uses.select(&:refill).map(&:id)).each(&:reset!).map(&:name)
    text = "#{short_name} pushes for #{talent.name} and #{took}#{"; #{refilled.to_sentence} refills" if refilled.any?}."
    Roll.note!(campaign: campaign, by: by, character: self, text: text) if campaign
    took
  end

  private
    # A fixed number of dice rolled now, as an action roll (Animal Companion's
    # tricks): the result and log like a stat's, and a disaster gives spark.
    def roll_for_talent!(talent, roll, by:, random: Random)
      result = Grimwild::Dice.roll(roll.dice, 0, random: random)
      transaction do
        spend_for_roll!(roll)
        gained = settle_spark(take: result.result == "disaster")
        save!
        rolls.create!(campaign: campaign, identity: by, kind: "action", name: name, stat: roll.as, stat_dice: roll.dice,
          dice: result.dice, thorns: [], outcome: result.result, critical: result.critical, spark_gained: gained,
          question: "#{talent.name}: #{roll.label}")
      end
    end

    def spend_for_roll!(roll)
      if roll.thread.positive?
        raise ArgumentError, "#{name} has no thread left to spend." if thread < roll.thread
        update!(thread: thread - roll.thread)
      end
      if (use = use_counters.find { _1.id == roll.use_id })
        raise ArgumentError, "No #{use.label.downcase} left this #{use.per}." unless uses_left(use).positive?
        spend_use!(use.id, spent: uses_spent(use) + 1)
      end
    end
end
