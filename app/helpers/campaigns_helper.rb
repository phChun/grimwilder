module CampaignsHelper
  # What a character still has to pick, for the GM table's party card: "Picks
  # to make: 1 talent, 2 skills (Expertise)". Nil when there's nothing.
  def picks_to_make_line(character)
    picks = [ (pluralize(character.talents_to_choose, "talent") if character.talents_to_choose.positive?),
      *character.choices_to_make.map { |talent, choice, left| "#{left} #{choice.nouns(left)} (#{talent.name})" } ].compact
    "Picks to make: #{picks.join(", ")}" if picks.any?
  end

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
    character.use_counters.map { "#{_1.label} #{character.uses_left(_1)}/#{character.use_count(_1)}" }.join(" · ")
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
    vex = "Vex: #{character.vex}#{" (#{character.vex_subject})" if character.vex_subject}" if character.vex
    (harm + marks + character.conditions.pluck("name") + [ vex ].compact).join(" · ").presence
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

  # The composer's speak-as choices, as [label, value]: a player's characters,
  # table talk and whispers to the GM and each other player; the GM's
  # narration, an NPC, table talk and a whisper to each player. A whisper's
  # data-thread is the other side, as feed_filters names it.
  def speak_as_voices(campaign, membership, speakers)
    whispers = whisper_characters(campaign, membership).map { [ "Privately to #{_1.short_name}", "whisper:#{_1.id}", { data: { thread: _1.identity_id } } ] }
    if membership.gm?
      [ %w[ Narrate narration ], [ "As NPC", "npc" ], [ "Table talk", "table_talk" ], *whispers ]
    else
      speakers.map { [ "As #{_1.short_name}", "character:#{_1.id}" ] } + [ [ "Table talk", "table_talk" ], [ "Privately to the GM", "whisper", { data: { thread: "gm" } } ], *whispers ]
    end
  end

  # The rail's Show choices. Private conversations are one per person you can
  # whisper with, so you pick whose to read rather than seeing them all at
  # once: the GM's with each player, a player's with the GM and each other
  # player (named by their active characters here).
  def feed_filters(campaign, membership)
    names = whisper_characters(campaign, membership).group_by(&:identity_id)
    players = campaign.memberships.player.includes(:identity).where.not(identity_id: membership.identity_id)
    threads = players.map { [ "Private: #{names[_1.identity_id]&.map(&:short_name)&.to_sentence || _1.identity.display_name}", "private-#{_1.identity_id}" ] }
    threads.unshift([ "Private with the GM", "private-gm" ]) unless membership.gm?
    # data-label keeps the plain name: feed_controller.js adds "· 2 new" to the shown one.
    threads = threads.map { |label, value| [ label, value, { data: { label: label } } ] }
    [ %w[ Everything all ], %w[ Story story ], [ "Table talk", "talk" ], %w[ Dice dice ], *threads ]
  end

  # Other players' active characters here: who you can whisper to.
  def whisper_characters(campaign, membership)
    players = campaign.memberships.player.where.not(identity_id: membership.identity_id).select(:identity_id)
    campaign.characters.played.active.where(identity_id: players).order(:name)
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
