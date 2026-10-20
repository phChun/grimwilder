module CharactersHelper
  DAMAGE_SOURCES = { "marked" => "the mark", "bloodied" => "Bloodied", "rattled" => "Rattled", "desperate" => "Desperate" }.freeze

  # A character's owner and their campaign's GM can tick talent uses, and mark
  # harm, marks and conditions.
  def can_spend_talent_uses?(character)
    character.tended_by?(Current.identity)
  end
  alias_method :can_change_damage?, :can_spend_talent_uses?

  # "1 thorn from the mark, already added"
  def damage_thorns_note(character, stat)
    reasons = character.damage_reasons(stat)
    "#{pluralize(reasons.size, "thorn")} from #{reasons.map { DAMAGE_SOURCES.fetch(_1) }.to_sentence}, already added" if reasons.any?
  end

  # "Roll 3d + 1t"; stat_roll_controller.js keeps it current as the steppers change.
  def stat_roll_label(dice, thorns)
    "Roll #{dice}d#{" + #{thorns}t" if thorns.positive?}"
  end

  # "Agility · just now", "Wits defense · 5 minutes ago"
  def roll_toast_heading(roll)
    when_rolled = roll.created_at > 1.minute.ago ? "just now" : "#{time_ago_in_words(roll.created_at)} ago"
    [ "#{roll.stat.capitalize}#{" defense" if roll.defense?}", when_rolled ].join(" · ")
  end

  # The sheet shows its newest roll as a toast for this long after it was made
  # or changed (taking spark for a critical changes it).
  ROLL_TOAST_SECONDS = 30

  def roll_toast?(character, roll, editable)
    roll.present? && (roll_toast_seconds_left(roll).positive? || roll_toast_sticky?(character, roll, editable))
  end

  def roll_toast_seconds_left(roll)
    [ (ROLL_TOAST_SECONDS - (Time.current - roll.updated_at)).ceil, 0 ].max
  end

  # A critical waiting on its choice stays until it's closed.
  def roll_toast_sticky?(character, roll, editable)
    editable && character.can_take_spark_for?(roll)
  end

  # Changes when the roll does, so a closed toast comes back for news.
  def roll_toast_key(roll)
    "roll-#{roll.id}-#{roll.updated_at.to_i}"
  end

  # "GM cleared Bloodied · 3 minutes ago", for a change the owner didn't make.
  def harm_change_line(character)
    who = character.harm_changed_by
    name = character.campaign&.gms&.include?(who) ? "GM" : who&.display_name || "Someone"
    "#{name} #{character.harm_change} · #{time_ago_in_words(character.harm_changed_at)} ago"
  end
end
