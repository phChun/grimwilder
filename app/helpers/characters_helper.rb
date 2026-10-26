module CharactersHelper
  DAMAGE_SOURCES = { "marked" => "the mark", "bloodied" => "Bloodied", "rattled" => "Rattled", "desperate" => "Desperate", "flesh wound" => "a Flesh Wound" }.freeze

  # A character's owner and their campaign's GM can tick talent uses, and mark
  # harm, marks and conditions.
  def can_spend_talent_uses?(character)
    character.tended_by?(Current.identity)
  end
  alias_method :can_change_damage?, :can_spend_talent_uses?

  # A talent pick as the sheet shows it: "Wild Fire · Evocation" for a theorem.
  def talent_pick_label(choice, pick)
    name, school = choice.schooled? ? Talent::Choice.split_school(pick) : [ pick, nil ]
    [ title_case(name), school&.capitalize ].compact.join(" · ")
  end

  # "1 thorn from the mark, already added"
  def damage_thorns_note(character, stat)
    reasons = character.damage_reasons(stat)
    "#{pluralize(reasons.size, "thorn")} from #{reasons.map { DAMAGE_SOURCES.fetch(_1) }.to_sentence}, already added" if reasons.any?
  end

  # A named box's title: "Burn Fire", "Charged: spend Fire", "Mark Harm".
  def use_word_title(use, name, spent)
    case use.verb
    when "charge" then spent ? "Charged: spend #{name}'s charge" : "Charge #{name}"
    when "mark" then spent ? "Marked: clear #{name}" : "Mark #{name}"
    else spent ? "Burned: restore #{name}" : "Burn #{name}"
    end
  end

  # "2 left", "1 charged", "1 marked".
  def use_words_left(use, total, spent)
    case use.verb
    when "charge" then "#{spent} charged"
    when "mark" then spent.zero? ? "unhurt" : "#{spent} marked"
    else "#{total - spent} left"
    end
  end

  # A talent's tick in the roll setup: "Using a chosen skill (Duel, Stealth)".
  def talent_bonus_label(character, talent, bonus)
    picks = (choice = talent.choice(bonus.choice)) ? character.picks_for(choice).map { talent_pick_label(choice, _1) } : []
    [ bonus.label, ("(#{picks.join(", ")})" if picks.any?) ].compact.join(" ")
  end

  # What ticking it does: "+1d", "+2d · defense only", "1 of 3 left".
  def talent_bonus_effect(character, bonus, stat)
    dice = character.bonus_dice(bonus, stat)
    use = character.bonus_use(bonus)
    thorns = character.bonus_thorns(bonus)
    [ ("+#{dice}d" if dice.positive?), ("+#{thorns}t" if thorns.positive?), ("defense only" if bonus.defense_only?),
      ("#{character.uses_left(use)} of #{use.count_at(character.level)} left" if use) ].compact.join(" · ")
  end

  # "Roll 3d + 1t"; stat_roll_controller.js keeps it current as the steppers change.
  def stat_roll_label(dice, thorns)
    "Roll #{dice}d#{" + #{thorns}t" if thorns.positive?}"
  end

  # "GM cleared Bloodied · 3 minutes ago", for a change the owner didn't make.
  def harm_change_line(character)
    who = character.harm_changed_by
    name = character.campaign&.gms&.include?(who) ? "GM" : who&.display_name || "Someone"
    "#{name} #{character.harm_change} · #{time_ago_in_words(character.harm_changed_at)} ago"
  end
end
