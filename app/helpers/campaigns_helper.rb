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

  # "Inspiration 2/3 · Mastery 1/2": uses left this session or scene.
  def talent_use_summary(character)
    character.use_counters.map { "#{_1.label} #{character.uses_left(_1)}/#{_1.count_at(character.level)}" }.join(" · ")
  end

  def pool_reset_label(pool)
    first = pool.phases.first
    pool.linked? ? "Reset to #{first["size"]}d #{first["name"]}" : "Reset to #{pool.starting_size}d"
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

  # --- the campaign page ----------------------------------------------------

  # A scene's outcome in a few words, for "Previously on…": how it closed, a
  # quarrel or a pool running out in it, or how it opened.
  def scene_outcome(scene)
    if (closing = scene.closing_roll)
      "montage · #{closing.outcome}"
    elsif (quarrel = scene.rolls.quarrel.recent.first)
      "quarrel · #{quarrel.tie? ? "a tie" : "#{quarrel.winner} won"}"
    elsif (ran_out = scene.rolls.pool.where(remaining: 0).recent.first)
      "#{ran_out.name} ran out"
    elsif (opening = scene.opening_roll)
      "story roll · #{opening.outcome}"
    end
  end

  def session_date(session)
    session.started_at.strftime("%a, %b %-d")
  end

  # "4 scenes · 31 rolls"
  def session_counts(session)
    rolls = session.rolls.where.not(kind: %w[ marker note ]).count
    [ pluralize(session.scenes.size, "scene"), pluralize(rolls, "roll") ].join(" · ")
  end

  # Who a member is at the table: "GM", the character they play, or "making one".
  def member_role(membership, characters)
    return "GM" if membership.gm?
    characters.find { _1.identity_id == membership.identity_id && _1.active? }&.short_name || "making one"
  end

  # "Brother Oake, Cleric 3, fallen"
  def gone_line(character)
    "#{character.path} #{character.level}, #{character.status}"
  end

  # The composer's first speak-as choice: the GM narrates during a session; a
  # player speaks as their character if they have one here.
  def default_voice(membership, speakers, speaker)
    if membership.gm? then membership.campaign.current_session ? "narration" : "table_talk"
    elsif (character = speaker || speakers.first) then "character:#{character.id}"
    else "table_talk"
    end
  end
end
