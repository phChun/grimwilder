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
    conditions = character.conditions.map { tag.span(_1, class: "status-chip") }
    safe_join(harm + marks + conditions)
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
end
