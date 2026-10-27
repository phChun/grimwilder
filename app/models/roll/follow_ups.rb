# Talents that change a roll after it's made (Talent::FollowUp): Luck's bonus
# die, Blessed's re-roll, an ally's Inspiration raising a die, Got Your Back's
# late assist. Only a character's action, defense or story roll, while it's
# still their latest and fresh (WINDOW), at a table still in play.
#
# Each changes the roll in place (its dice, thorns, assists and result) and
# adds an entry to `follow_ups`, so the log can say what happened, and the
# update replaces the log entry live. Spark already taken for a disaster stays
# taken if a follow-up lifts it.
module Roll::FollowUps
  extend ActiveSupport::Concern

  WINDOW = 15.minutes
  KINDS = %w[ action defense story ].freeze

  def follow_up_open?
    kind.in?(KINDS) && created_at > WINDOW.ago && character_id.present? && campaign.present? && !campaign.done? &&
      character.rolls.where(kind: KINDS).recent.first == self
  end

  # [actor, talent, follow-up] for each thing these characters could do to
  # this roll now: the roller's own talents, and those of others seated at the
  # same table.
  def follow_ups_for(characters)
    return [] unless follow_up_open?

    characters.flat_map do |actor|
      own = actor.id == character_id
      actor = character if own
      next [] unless own || (actor.campaign_id == campaign_id && actor.in_play?)

      [ *actor.talent_entries, *actor.eldritch_talent_entries ].flat_map do |talent|
        talent.follow_ups.select { follow_up_fits?(actor, _1, own) }.map { [ actor, talent, _1 ] }
      end
    end
  end

  # die: the value a raise lifts by 1, or an omen replaces; omen: its value.
  def follow_up!(actor, follow_up_id, by:, die: nil, omen: nil, random: Random)
    with_lock do
      actor.reload unless actor.id == character_id # the roller's own comes fresh with the lock
      offered = follow_ups_for([ actor ]).find { _3.id == follow_up_id.to_s }
      raise ArgumentError, "That talent can't change this roll now." unless offered

      actor, talent, follow_up = offered
      die = Integer(die, exception: false) if follow_up.kind.in?(%w[ raise omen ])
      raise ArgumentError, "Pick a die below 6 to raise." if follow_up.kind == "raise" && !(die&.between?(1, 5) && all_dice.include?(die))
      if follow_up.kind == "omen"
        omen = Integer(omen, exception: false)
        raise ArgumentError, "Pick a die and one of #{actor.short_name}'s omens." unless die && all_dice.include?(die) && actor.omens.include?(omen) && die != omen
      end
      entry = { "id" => follow_up.id, "kind" => follow_up.kind, "talent" => talent.name, "by" => actor.name, "character_id" => actor.id, "was_outcome" => outcome }

      transaction do
        if (use = actor.use_counters.find { _1.id == follow_up.use_id })
          actor.talent_uses = actor.talent_uses.merge(use.id => actor.uses_spent(use) + 1)
        end
        if follow_up.pool
          entry["pool_dice"] = follow_up_pool(actor, follow_up).roll_into!(by: by, random: random)
        elsif follow_up.dice
          entry["pool_dice"] = Array.new(follow_up.dice) { random.rand(1..6) }
        end
        entry["critical_effect"] = true if follow_up.six == "critical_effect" && entry["pool_dice"]&.include?(6)

        apply_follow_up(follow_up, entry, actor, die: die, omen: omen, random: random)
        result = interpretation
        self.outcome, self.critical = result.result, result.critical
        entry["spark"] = follow_up_spark(follow_up, entry, actor).select { _1.settle_spark(take: true) }.map(&:name)
        self.follow_ups = follow_ups + [ entry ]

        actor.save!
        character.save! unless actor == character
        save!
      end
      # An ally changed it: the roller's open sheet shows the new result.
      character.broadcast_refresh_later unless actor == character
    end
  end

  # The result as first rolled, before any follow-up.
  def first_outcome
    follow_ups.first&.dig("was_outcome") || outcome
  end

  private
    def follow_up_fits?(actor, follow_up, own)
      follow_up.for_roller?(own) && follow_up.rolls.include?(kind) &&
        (follow_up.results.empty? || follow_up.results.include?(outcome)) &&
        (follow_up.after.nil? || talent_bonuses.any? { _1["id"] == follow_up.after }) &&
        (follow_up.repeatable? || follow_ups.none? { _1["id"] == follow_up.id && _1["character_id"] == actor.id }) &&
        (!follow_up.use || actor.use_counters.find { _1.id == follow_up.use_id }&.then { actor.uses_left(_1).positive? }) &&
        (!follow_up.pool || follow_up_pool(actor, follow_up)&.size.to_i.positive?) &&
        (!follow_up.needs || actor.public_send(follow_up.needs).any?) &&
        case follow_up.kind
        when "reroll" then follow_ups.empty? # "a roll you just made"
        when "raise" then all_dice.any? { _1 < 6 }
        when "assist" then assists.none? { _1["character_id"] == actor.id }
        when "omen" then actor.omens.any? { |omen| all_dice.any? { _1 != omen } }
        else true
        end
    end

    def follow_up_pool(actor, follow_up)
      actor.talent_pools.find_by(use_key: follow_up.pool_id)
    end

    def apply_follow_up(follow_up, entry, actor, die:, omen:, random:)
      case follow_up.kind
      when "bonus"
        self.dice = dice + entry["pool_dice"]
      when "reroll"
        entry["was"], entry["was_thorns"] = dice, thorns
        self.dice, self.thorns = Array.new(dice.size) { random.rand(1..6) }, []
      when "raise"
        set_die(die, die + 1, entry)
      when "omen"
        set_die(die, omen, entry)
        actor.erase_omen(omen)
      when "assist"
        entry["die"] = random.rand(1..6)
        self.assists = assists + [ { "character_id" => actor.id, "name" => actor.name, "die" => entry["die"] } ]
      end
    end

    # The roller's own die if one shows that value, else an assist's.
    def set_die(value, to, entry)
      if (index = dice.index(value))
        self.dice = dice.dup.tap { _1[index] = to }
      else
        index = assists.index { _1["die"] == value }
        self.assists = assists.map.with_index { |assist, i| i == index ? assist.merge("die" => to) : assist }
      end
      entry["from"], entry["to"] = value, to
    end

    def follow_up_spark(follow_up, entry, actor)
      case follow_up.spark
      when "six" then entry["pool_dice"].include?(6) ? [ character ] : []
      when "grim_die" then entry["pool_dice"].any? { _1 <= 3 } ? [ actor ] : []
      when "perfect" then outcome == "perfect" ? [ actor ] : []
      when "perfect_both" then outcome == "perfect" ? [ actor, character ].uniq : []
      else []
      end
    end
end
