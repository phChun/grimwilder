module CampaignsHelper
  HARM = %w[ bloodied rattled desperate ].freeze

  # Each player at the table with their seated characters (none yet is fine),
  # plus a GM who has seated one.
  def table_seats(memberships, characters)
    memberships.filter_map do |membership|
      seated = characters.select { _1.identity_id == membership.identity_id }
      [ membership, seated ] if membership.player? || seated.any?
    end
  end

  # Chips under a character: harm (filled), marked stats, then conditions.
  def character_chips(character)
    harm = HARM.select { character.public_send(:"#{_1}?") }.map { tag.span(_1.capitalize, class: "status-chip status-chip--harm") }
    marks = Grimwild::STATS.select { character.marked?(_1) }.map { tag.span("#{_1.capitalize} marked", class: "status-chip status-chip--mark") }
    conditions = character.conditions.map { tag.span(_1["name"], class: "status-chip", title: ("Clears after scene" if _1["lasts"] == "scene")) }
    safe_join(harm + marks + conditions)
  end

  # "Inspiration 2/3 · Mastery 1/2": uses left this session or scene.
  def talent_use_summary(character)
    character.use_counters.map { "#{_1.label} #{character.uses_left(_1)}/#{_1.count_at(character.level)}" }.join(" · ")
  end

  def spark_dots(character)
    dots = Array.new(Grimwild::MAX_SPARK) { |index| tag.span(class: [ "spark-dot", ("spark-dot--held" if index < character.spark) ]) }
    tag.span(safe_join(dots), class: "spark-dots", role: "img", "aria-label": "#{character.spark} of #{Grimwild::MAX_SPARK} spark")
  end

  # The first harm at the table, for a collapsed summary: "Tibbs bloodied".
  def table_alert(characters)
    characters.each do |character|
      harm = HARM.find { character.public_send(:"#{_1}?") }
      return "#{character.name} #{harm}" if harm
    end
    nil
  end

  def pool_reset_label(pool)
    first = pool.phases.first
    pool.linked? ? "Reset to #{first["size"]}d #{first["name"]}" : "Reset to #{pool.starting_size}d"
  end

  # A log entry in a few words, for a collapsed summary: "Tibbs, Agility".
  def roll_headline(roll)
    case roll.kind
    when "action", "defense" then "#{roll.name}, #{roll.stat.capitalize}"
    when "story" then "#{roll.name}, story roll"
    when "quarrel" then "Quarrel: #{quarrel_result(roll)}"
    when "montage" then "Montage"
    else roll.name
    end
  end

  # "1h 12m", "8m": how long something has been going.
  def running_for(time)
    hours, minutes = ((Time.current - time) / 60).floor.divmod(60)
    hours.positive? ? "#{hours}h #{minutes}m" : "#{minutes}m"
  end

  # A party card's harm line: "Bloodied · Agility marked · 4d poisoned", or "No harm".
  def harm_line(character)
    harm = HARM.select { character.public_send(:"#{_1}?") }.map(&:capitalize)
    marks = Grimwild::STATS.select { character.marked?(_1) }.map { "#{_1.capitalize} marked" }
    (harm + marks + character.conditions.pluck("name")).join(" · ").presence
  end

  # "Pressure · everyone sees", "Timer · hidden from players", "Resource · ran out 20 minutes ago"
  def pool_card_meta(pool)
    seen = pool.hidden? ? "hidden from players" : "everyone sees"
    if pool.depleted? && pool.resource? && pool.last_rolled_at
      "#{pool.kind.capitalize} · ran out #{time_ago_in_words(pool.last_rolled_at)} ago"
    else
      "#{pool.kind.capitalize}#{" · linked" if pool.linked?} · #{seen}"
    end
  end

  # A card shows the last roll's dice when it was rolled (not pushed) this scene.
  def pool_card_shows_last_roll?(pool, scene)
    pool.last_dice.any? && pool.last_action != "pushed" && (scene.nil? || pool.last_rolled_at >= scene.started_at)
  end

  # "6d → 4d · 2 minutes ago" after a roll; nil when the pool hasn't changed hands.
  def pool_card_change(pool)
    return if pool.last_action.blank? || pool.last_rolled_at.nil?
    before = pool.linked? ? nil : pool.size + pool.last_dropped.to_i
    [ ("#{before}d → #{pool.size}d" if before), "#{time_ago_in_words(pool.last_rolled_at)} ago" ].compact.join(" · ")
  end
end
