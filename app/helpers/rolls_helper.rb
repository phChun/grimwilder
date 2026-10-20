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

  def roll_result_text(roll)
    RESULT_TEXT.fetch(roll.kind).fetch(roll.outcome)
  end

  # d6s (then any assist dice, dashed and named), then thorns as d8 rings.
  # Action and defense rolls light up the die that set the result (every 6 on
  # a critical); pool rolls light up the dice that stay and strike out the ones
  # that drop, and mark a power pool's spark dice, which never drop.
  def roll_dice_tags(roll, small: false, size: small ? 32 : 44)
    highest = roll.all_dice.max
    lit_one = false
    light = ->(value) do
      if roll.pool? then value >= 4 ? :highest : :dropped
      elsif value == highest && (!lit_one || roll.critical?) then lit_one = true; :highest
      end
    end

    pool_dice = roll.pool? ? roll.dice.size - roll.spark_spent : roll.dice.size
    d6s = roll.dice.map.with_index do |value, index|
      if index < pool_dice
        die_tag(value, state: light.(value), size: size)
      else
        die_tag(value, size: size, extra: "die--spark", aria_label: "spark die showing #{value}", title: "Spark")
      end
    end
    assists = roll.assists.map do |assist|
      die_tag(assist["die"], state: light.(assist["die"]), size: size, extra: "die--assist", aria_label: "#{assist["name"]}'s assist die showing #{assist["die"]}", title: assist["name"])
    end
    d8s = roll.thorns.map { |value| die_tag(value, kind: "d8", size: size) }

    safe_join(d6s + assists + d8s)
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
    result = Grimwild::Dice.interpret(roll.all_dice, roll.thorns)

    if result.critical?
      "More than one 6, so thorns can't cut it"
    elsif result.applied_cuts.positive?
      base = Grimwild::Dice::RESULTS[Grimwild::Dice::RESULTS.index(result.result) - result.applied_cuts]
      thorns = result.applied_cuts == 1 ? "a thorn" : "#{result.applied_cuts} thorns"
      "#{base.capitalize}, cut to #{result.result} by #{thorns}"
    elsif roll.thorns.any?
      "Highest die #{result.highest}, and no thorn cut it"
    else
      "Highest die #{result.highest}"
    end
  end

  # "3d Agility + 1 spark + 1d extra + Wren assisting, vs 2t (marked, 1 situational)",
  # or for a story roll "2d (even odds) + 1 spark, vs 1t (1 situational)"
  def roll_setup(roll)
    dice = [ roll.story? ? "#{roll.stat_dice}d (#{roll.odds})" : "#{roll.stat_dice}d #{roll.stat.capitalize}" ]
    dice << "#{roll.spark_spent} spark" if roll.spark_spent.positive?
    dice << "#{roll.help_dice}d extra" if roll.help_dice.positive?
    dice << "#{roll.assists.pluck("name").to_sentence} assisting" if roll.assists.any?

    thorns = roll.damage_reasons.dup
    thorns << "#{roll.situational_thorns} situational" if roll.situational_thorns.positive?

    [ dice.join(" + "), ("vs #{roll.thorns.size}t (#{thorns.join(", ")})" if thorns.any?) ].compact.join(", ")
  end

  def roll_summary(roll)
    result = Grimwild::Dice.interpret(roll.all_dice, roll.thorns)

    if result.critical?
      "Multiple 6s: a critical, so thorns can't cut it."
    else
      [ "Highest d6: #{result.highest}", ("#{pluralize(result.cuts, "cut")}#{" (#{result.applied_cuts} applied)" if result.applied_cuts < result.cuts}" if result.cuts.positive?) ].compact.join(" · ")
    end
  end

  def roll_spark_note(roll)
    who = roll.pool? ? roll.character&.name : roll.name
    return unless who

    if roll.spark_gained? && roll.critical?
      "Critical: nothing fit, so #{who} takes spark."
    elsif roll.spark_gained?
      "Disaster: #{who} takes spark."
    elsif roll.disaster?
      "Disaster: #{who} already holds #{Grimwild::MAX_SPARK} spark."
    end
  end

  def quarrel_result(roll)
    roll.tie? ? "Tie" : "#{roll.winner} wins"
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
    when "rolled_after_drop" then "Dropped 1d, then rolled #{roll.dice.size}d: #{roll.dropped}d dropped in all. #{left}"
    else "Rolled #{roll.dice.size}d: #{roll.dropped.zero? ? "nothing dropped" : "#{roll.dropped}d dropped"}. #{left}"
    end
  end
end
