module CharactersHelper
  DAMAGE_SOURCES = { "marked" => "the mark", "bloodied" => "Bloodied", "rattled" => "Rattled", "desperate" => "Desperate" }.freeze

  # A character's owner and their campaign's GM can tick talent uses.
  def can_spend_talent_uses?(character)
    character.owned_by?(Current.identity) ||
      (character.campaign && Current.identity&.membership_in(character.campaign)&.gm?)
  end

  # "1 thorn from the mark, already added"
  def damage_thorns_note(character, stat)
    reasons = character.damage_reasons(stat)
    "#{pluralize(reasons.size, "thorn")} from #{reasons.map { DAMAGE_SOURCES.fetch(_1) }.to_sentence}, already added" if reasons.any?
  end

  # "Roll 3d + 1t"; stat_roll_controller.js keeps it current as the steppers change.
  def stat_roll_label(dice, thorns)
    "Roll #{dice}d#{" + #{thorns}t" if thorns.positive?}"
  end

  # "Last roll · Agility · just now", "Last roll · Wits defense · 5 minutes ago"
  def last_roll_heading(roll)
    when_rolled = roll.created_at > 1.minute.ago ? "just now" : "#{time_ago_in_words(roll.created_at)} ago"
    [ "Last roll", "#{roll.stat.capitalize}#{" defense" if roll.defense?}", when_rolled ].join(" · ")
  end

  # "GM cleared Bloodied · 3 minutes ago", for a change the owner didn't make.
  def harm_change_line(character)
    who = character.harm_changed_by
    name = character.campaign&.gms&.include?(who) ? "GM" : who&.display_name || "Someone"
    "#{name} #{character.harm_change} · #{time_ago_in_words(character.harm_changed_at)} ago"
  end
end
