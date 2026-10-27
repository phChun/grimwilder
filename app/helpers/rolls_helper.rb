module RollsHelper
  RESULT_TEXT = {
    "action" => {
      "perfect" => "Success, and you avoid trouble.",
      "messy" => "Success, with an impact move.",
      "grim" => "Failure, with an impact move.",
      "disaster" => "Failure, with a worse impact move."
    },
    "defense" => {
      "perfect" => "You avoid the impact move.",
      "messy" => "You reduce the impact move.",
      "grim" => "You take the full impact move.",
      "disaster" => "You take a worse impact move."
    },
    "story" => {
      "perfect" => "It goes your way.",
      "messy" => "It goes your way, with a problem.",
      "grim" => "It goes against you.",
      "disaster" => "It goes against you, badly."
    }
  }.freeze

  # The roll you just made shows as a toast (rolls/_toast, in the layout) on
  # whatever page you land on, for this long after it was made or changed
  # (taking spark for a critical changes it).
  ROLL_TOAST_SECONDS = 10

  # Your newest roll, while it's still toast-worthy.
  def toast_roll
    return unless Current.identity
    return @toast_roll if defined?(@toast_roll)

    # A roll call's result shows in its own modal instead.
    roll = Roll.where(identity: Current.identity).where.not(kind: %w[ marker note ]).where.missing(:roll_call).order(updated_at: :desc, id: :desc).first
    @toast_roll = roll if roll && (roll_toast_seconds_left(roll).positive? || roll_toast_sticky?(roll))
  end

  def roll_toast_seconds_left(roll)
    [ (ROLL_TOAST_SECONDS - (Time.current - roll.updated_at)).ceil, 0 ].max
  end

  # A critical waiting on its owner's choice stays until it's closed.
  def roll_toast_sticky?(roll)
    character = roll.character
    character.present? && character.identity_id == Current.identity&.id && character.can_take_spark_for?(roll)
  end

  # Changes when the roll does, so a closed toast comes back for news.
  def roll_toast_key(roll)
    "roll-#{roll.id}-#{roll.updated_at.to_i}"
  end

  # "Gibbles · Agility defense · just now", "Story roll · 5 minutes ago"
  def roll_toast_heading(roll)
    what =
      case roll.kind
      when "action", "defense" then "#{roll.name} · #{roll.stat.capitalize}#{" defense" if roll.defense?}"
      when "story" then "#{"#{roll.name} · " if roll.character}Story roll"
      when "montage" then "Montage · #{roll.name}"
      when "quarrel" then "Quarrel · #{roll.name}"
      else "#{roll.name}#{": #{roll.phase}" if roll.phase}#{", as an action" if roll.outcome}"
      end
    when_rolled = roll.created_at > 1.minute.ago ? "just now" : "#{time_ago_in_words(roll.created_at)} ago"
    "#{what} · #{when_rolled}"
  end

  def roll_result_text(roll)
    RESULT_TEXT.fetch(roll.kind).fetch(roll.outcome)
  end

  # d6s (then any assist dice, dashed and named), then thorns as d8 rings.
  # Action and defense rolls light up the die that set the result (every 6 on
  # a critical); pool rolls light up the dice that stay and strike out the ones
  # that drop, and mark a power pool's spark dice, which never drop.
  def roll_dice_tags(roll, small: false, size: small ? 32 : 44)
    counted = roll.counted_dice
    highest = counted.max
    lit_one = false
    light = ->(value) do
      if roll.pool? then value >= 4 ? :highest : :dropped
      elsif value == highest && (!lit_one || roll.critical?) then lit_one = true; :highest
      end
    end
    counts = ->(value, as) { as == value ? {} : { counts_as: as, title: "Counts as #{as}" } }

    pool_dice = roll.pool? ? roll.dice.size - roll.spark_spent : roll.dice.size
    d6s = roll.dice.map.with_index do |value, index|
      if index < pool_dice
        die_tag(value, state: light.(counted[index]), size: size, **counts.(value, counted[index]))
      else
        die_tag(value, size: size, extra: "die--spark", aria_label: "spark die showing #{value}", title: "Spark")
      end
    end
    assists = roll.assists.map.with_index do |assist, index|
      as = counted[roll.dice.size + index]
      die_tag(assist["die"], state: light.(as), size: size, extra: "die--assist", aria_label: "#{assist["name"]}'s assist die showing #{assist["die"]}",
        title: [ assist["name"], assist["talent"], ("counts as #{as}" if as != assist["die"]) ].compact.join(" · "), counts_as: (as if as != assist["die"]))
    end
    d8s = roll.thorns.map { |value| die_tag(value, kind: "d8", size: size) }
    boosts = roll.boosts.map { |value| die_tag(value, kind: "d8", size: size, extra: "die--panache", aria_label: "panache die showing #{value}", title: "Panache") }

    safe_join(d6s + assists + d8s + boosts)
  end

  def die_tag(value, **options)
    render "shared/die", value: value, **options
  end

  # The word a result card shows: Perfect, Messy, Grim, Disaster or Critical.
  def roll_result_word(roll)
    roll.critical? ? "Critical" : roll.outcome.capitalize
  end

  def roll_result_tier(roll)
    roll.critical? ? "critical" : roll.outcome
  end

  # One line on how the dice got there: "Messy, cut to grim by a thorn".
  def roll_reason(roll)
    result = roll.interpretation
    reason =
      if result.critical?
        "More than one 6, so thorns can't cut it"
      elsif result.applied_cuts.positive?
        base = Grimwild::Dice::RESULTS[Grimwild::Dice::RESULTS.index(result.result) - result.applied_cuts + result.applied_boosts]
        thorns = result.applied_cuts == 1 ? "a thorn" : "#{result.applied_cuts} thorns"
        "#{base.capitalize}, cut to #{result.result} by #{thorns}"
      elsif result.applied_boosts.positive?
        base = Grimwild::Dice::RESULTS[Grimwild::Dice::RESULTS.index(result.result) + result.applied_boosts]
        "#{base.capitalize}, raised to #{result.result} by #{result.applied_boosts == 1 ? "a panache die" : "#{result.applied_boosts} panache dice"}"
      elsif roll.thorns.any?
        "Highest die #{result.highest}, and no thorn cut it"
      else
        "Highest die #{result.highest}"
      end
    reason += ", with 5s as 6s and 4s as 1s" if roll.reckless?
    roll.magical_twist? ? "#{reason}. Magical twist: two or more 1s" : reason
  end

  # "3d Agility + 1d Expertise + 1 spark + 1d extra + Wren assisting, vs 2t (marked, 1 situational)",
  # or for a story roll "2d (even odds) + 1 spark, vs 1t (1 situational)"
  def roll_setup(roll)
    dice = [ roll.story? ? "#{roll.stat_dice}d (#{roll.odds})" : "#{roll.stat_dice}d #{roll.stat.capitalize}" ]
    dice << "#{roll.spark_spent} spark" if roll.spark_spent.positive?
    roll.talent_bonuses.each { dice << "#{_1["dice"]}d #{_1["name"]}" if _1["dice"].positive? }
    dice << "#{roll.help_dice}d #{roll.help_from ? "from #{roll.help_from}" : "extra"}" if roll.help_dice.positive?
    dice << roll_assists_line(roll) if roll.assists.any?

    thorns = roll.damage_reasons.tally.map { |reason, count| count > 1 ? "#{count} #{reason}" : reason }
    thorns << "#{roll.situational_thorns} situational" if roll.situational_thorns.positive?

    left_out = roll.talent_bonuses.select { _1["ignored"].positive? }.map do |bonus|
      "#{bonus["name"]} left out #{pluralize(bonus["ignored"], "thorn")}#{" for #{roll.boosts.size == 1 ? "a panache die" : "#{roll.boosts.size} panache dice"}" if bonus["id"] == Character::Rolling::PANACHE && roll.boosts.any?}"
    end

    setup = [ dice.join(" + "), ("vs #{roll.thorns.size}t (#{thorns.join(", ")})" if thorns.any?), *left_out ].compact.join(", ")
    roll.follow_ups.any? ? "#{setup}; then #{roll.follow_ups.map { follow_up_line(_1) }.join("; ")}" : setup
  end

  # Whether the viewer's characters can do anything to this roll now: the
  # roll toast then links to the follow-ups.
  def roll_follow_ups_offered?(roll)
    membership = roll.campaign && Current.identity&.membership_in(roll.campaign)
    membership.present? && roll.follow_ups_for(membership.follow_up_characters).any?
  end

  # "2 of 3 left", "Luck 1d", for a follow-up's use or pool.
  def follow_up_cost(actor, follow_up)
    if (use = actor.use_counters.find { _1.id == follow_up.use_id })
      "#{actor.uses_left(use)} of #{use.count_at(actor.level)} #{use.label.downcase} left"
    elsif (pool = actor.talent_pools.find_by(use_key: follow_up.pool_id))
      "#{pool.name.split(": ").last} #{pool.size}d"
    end
  end

  def follow_up_button(actor, follow_up)
    case follow_up.kind
    when "bonus" then "Roll #{follow_up.dice || actor.talent_pools.find_by(use_key: follow_up.pool_id)&.size}d"
    when "reroll" then "Re-roll"
    when "assist" then "Assist with 1d"
    when "omen" then "Swap"
    else "Spend 1"
    end
  end

  # "Wren assisting (+1d Guardian)", "Bram and Wren assisting".
  def roll_assists_line(roll)
    extras = roll.assists.select { _1["talent"] }.group_by { _1["talent"] }.map { |talent, dice| "+#{dice.size}d #{talent}" }
    "#{roll.assists.pluck("name").uniq.to_sentence} assisting#{" (#{extras.join(", ")})" if extras.any?}"
  end

  # What a talent did after the roll: "Fen's Inspiration raised a 3 to 4",
  # "Luck +1d (2), and Tibbs takes spark".
  def follow_up_line(entry)
    whose = "#{entry["by"]}'s #{entry["talent"]}"
    line = case entry["kind"]
    when "bonus" then "#{whose} +#{entry["pool_dice"].size}d (#{entry["pool_dice"].join(", ")})#{": a 6, so add a critical effect" if entry["critical_effect"]}"
    when "reroll" then "#{whose} re-rolled it without thorns (it was #{entry["was"].join(", ")})"
    when "raise" then "#{whose} raised a #{entry["from"]} to #{entry["to"]}"
    when "assist" then "#{entry["by"]} assisted after the roll with #{entry["talent"]} (#{entry["die"]})"
    when "critical_effect" then "#{whose} adds a critical effect"
    when "omen" then "#{entry["by"]} swapped a #{entry["from"]} for an omen of #{entry["to"]} (#{entry["talent"]})"
    end
    Array(entry["spark"]).any? ? "#{line}, and #{entry["spark"].to_sentence} #{entry["spark"].one? ? "takes" : "take"} spark" : line
  end

  def roll_summary(roll)
    result = roll.interpretation

    if result.critical?
      "Multiple 6s: a critical, so thorns can't cut it."
    else
      [ "Highest d6: #{result.highest}", ("#{pluralize(result.cuts, "cut")}#{" (#{result.applied_cuts} applied)" if result.applied_cuts < result.cuts}" if result.cuts.positive?) ].compact.join(" · ")
    end
  end

  def roll_spark_note(roll)
    who = roll.pool? ? roll.character&.name : roll.name
    return unless who

    if roll.spark_gained? && roll.first_outcome == "disaster" && !roll.disaster?
      "It was a disaster at first, so #{who} took spark."
    elsif roll.spark_gained? && roll.critical?
      "Critical: nothing fit, so #{who} takes spark."
    elsif roll.spark_gained?
      "Disaster: #{who} takes spark."
    elsif roll.disaster?
      "Disaster: #{who} already holds #{Grimwild::MAX_SPARK} spark."
    end
  end

  # "Montage: perfect", or "Montage: critical (Teamwork)" when Teamwork's 6
  # joins another's.
  def montage_result(roll)
    if roll.critical? && roll.sides.none? { _1["critical"] }
      "Montage: critical (Teamwork)"
    else
      "Montage: #{roll.critical? ? "critical" : roll.outcome}"
    end
  end

  def quarrel_result(roll)
    roll.tie? ? "Tie" : "#{roll.winner} wins"
  end

  # What a quarrel side or montage character added to their 2d: " + 1 spark + 1d Jack of All Trades".
  def side_extras(side)
    extras = [ ("#{side["spark_spent"]} spark" if side["spark_spent"].positive?) ]
    extras += Array(side["talent_bonuses"]).select { _1["dice"].positive? }.map { "#{_1["dice"]}d #{_1["name"]}" }
    extras.compact.map { " + #{_1}" }.join
  end

  # A quarrel side's or montage character's own dice, then any helpers' assist
  # dice; the highest die lights up.
  def side_dice_tags(side)
    dice = side["dice"] + side["helpers"].pluck("die")
    top = dice.index(dice.max)
    tags = dice.map.with_index do |value, index|
      helper = side["helpers"][index - side["dice"].size] if index >= side["dice"].size
      die_tag(value, state: (:highest if index == top), size: 32, extra: ("die--assist" if helper),
        aria_label: (helper ? "#{helper["name"]}'s assist die showing #{value}" : nil), title: helper&.dig("name"))
    end
    safe_join(tags)
  end

  def quarrel_spark_note(roll)
    capped = roll.quarrelers.reject { _1["spark_gained"] }.pluck("name")
    "Everyone in it takes spark#{" (#{capped.to_sentence} already #{capped.one? ? "holds" : "hold"} #{Grimwild::MAX_SPARK})" if capped.any?}."
  end

  def pool_roll_summary(roll)
    left =
      if roll.next_phase then "0d: #{roll.phase} is done. #{roll.next_phase} begins."
      elsif roll.refilled? then "0d: #{roll.pool&.outcome || "it happens."} Then it refills to #{roll.pool&.starting_size}d."
      elsif roll.remaining.zero? then "0d: #{roll.pool&.outcome || "it happens."}"
      else "#{roll.remaining}d left."
      end

    if roll.outcome
      rolled = roll.dice.size - roll.spark_spent
      setup = [ "#{rolled}d", ("#{roll.spark_spent} spark" if roll.spark_spent.positive?) ].compact.join(" + ")
      setup += ", vs #{roll.thorns.size}t" if roll.thorns.any?
      first = "1d dropped first, then " if roll.pool_action == "rolled_after_drop"
      return "#{first}#{setup} as an action#{" for #{roll.character.name}" if roll.character}: #{roll.dropped}d dropped. #{left}"
    end

    case roll.pool_action
    when "pushed" then "Pushed: 1d dropped, take a mark. #{left}"
    when "ticked" then "Ticked: 1d dropped. #{left}"
    when "smite" then "#{roll.character&.name || "Someone"} smites: 1d dropped. #{left}"
    when "rolled_after_drop" then "Dropped 1d, then rolled #{roll.dice.size}d: #{roll.dropped}d dropped in all. #{left}"
    else "Rolled #{roll.dice.size}d: #{roll.dropped.zero? ? "nothing dropped" : "#{roll.dropped}d dropped"}. #{left}"
    end
  end
end
