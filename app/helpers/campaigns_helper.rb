module CampaignsHelper
  # The campaigns list's banner when a plan holds some of an account's
  # campaigns (Identity::Plans#apply_plan!).
  def plan_hold_message(identity, held)
    plan = identity.current_plan
    limit = plan.limit_for(:gm)
    names = held.map(&:name).to_sentence
    "You're on #{plan.name}, which runs #{pluralize(limit, "campaign")} at a time. #{names} #{held.many? ? "are" : "is"} on hold. Choose which to play, archive one, or upgrade."
  end

  # The confirm on Archive, in settings and on the campaigns list.
  def archive_confirmation(campaign)
    "Archive #{campaign.name}? Everyone can still read it, but nothing new is played there. You can unarchive it."
  end

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
  # The GM table's running clock (clock_controller.js counts on from here):
  # "12:34", or "1:12:05" past an hour.
  def clock_tag(since, label:)
    elapsed = [ (Time.current - since).floor, 0 ].max
    hours, rest = elapsed.divmod(3600)
    minutes, seconds = rest.divmod(60)
    text = hours.positive? ? format("%d:%02d:%02d", hours, minutes, seconds) : format("%d:%02d", minutes, seconds)
    tag.span(class: "scene-clock__item") do
      tag.span(label, class: "scene-clock__label") +
        tag.span(text, class: "scene-clock__time", role: "timer", "aria-label": "#{label} running", data: { controller: "clock", clock_elapsed_value: elapsed })
    end
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

  # The rail's Show choices, which also say where the composer sends: the
  # story views to the table in character (the GM narrating or voicing an
  # NPC), Table talk out of character, and a private conversation (one per
  # person you can whisper with, named by their active characters here) to
  # just them. Each carries the composer's data-to and data-placeholder;
  # data-label keeps the plain name of each view that counts unread (Story,
  # Table talk, each conversation), since feed_controller.js adds "· 2 new".
  def feed_filters(campaign, membership, speakers)
    story = { to: "To the table, in character", placeholder: story_placeholder(membership, speakers) }
    talk = { to: "To the table, out of character", placeholder: "Talk to the table, out of character…" }

    names = whisper_characters(campaign, membership).group_by(&:identity_id)
    players = campaign.memberships.player.includes(:identity).where.not(identity_id: membership.identity_id)
    threads = players.map do |player|
      name = names[player.identity_id]&.map(&:short_name)&.to_sentence || player.identity.display_name
      [ "Private: #{name}", "private-#{player.identity_id}", { to: "Privately to #{name}", placeholder: "Only #{name}#{"’s player" if names[player.identity_id]} and you see this…" } ]
    end
    threads.unshift([ "Private with the GM", "private-gm", { to: "Privately to the GM", placeholder: "Only the GM and you see this…" } ]) unless membership.gm?

    [ [ "Everything", "all", story ], [ "Story", "story", story ], [ "Table talk", "talk", talk ], [ "Dice", "dice", story ], *threads ].map do |label, value, data|
      [ label, value, { data: { label: (label unless %w[ all dice ].include?(value)), **data }.compact } ]
    end
  end

  def story_placeholder(membership, speakers)
    if membership.gm? then "Narrate the scene, or voice an NPC…"
    elsif speakers.one? then "What does #{speakers.first.short_name} say?"
    elsif speakers.any? then "Say it in character…"
    else "Talk to the table…"
    end
  end

  # Other players' active characters here: who you can whisper to.
  def whisper_characters(campaign, membership)
    players = campaign.memberships.player.where.not(identity_id: membership.identity_id).select(:identity_id)
    campaign.characters.played.active.where(identity_id: players).order(:name)
  end
end
