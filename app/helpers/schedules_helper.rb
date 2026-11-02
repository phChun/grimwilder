# Game dates in words (Campaign::Schedule): rendered in the schedule's time
# zone with its abbreviation ("Tonight, 7pm EST"), inside a <time> that
# local_time_controller.js rewrites in the viewer's zone when that differs.
module SchedulesHelper
  WEEKDAYS = Date::DAYNAMES.each_with_index.to_a.freeze
  WEEKS_OF_MONTH = [ [ "First", 1 ], [ "Second", 2 ], [ "Third", 3 ], [ "Fourth", 4 ], [ "Last", -1 ] ].freeze
  HOW_OFTEN = [ [ "Every week", "weekly-1" ], *(2..8).map { [ "Every #{_1} weeks", "weekly-#{_1}" ] }, [ "Monthly", "monthly" ], [ "Only dates I add", "dates" ] ].freeze

  # The time zones to pick from, by IANA name, with the schedule's own even if
  # it isn't one of Rails' named zones.
  def schedule_time_zones(selected)
    zones = ActiveSupport::TimeZone.all.map { [ "(GMT#{_1.formatted_offset}) #{_1.name}", _1.tzinfo.name ] }.uniq(&:last)
    zones.any? { _1.last == selected } || selected.blank? ? zones : [ [ selected, selected ], *zones ]
  end

  # style: :short ("Tonight, 7pm EST", "Sat, 7pm EST", "Sat Nov 14, 7pm EST"),
  # :date ("Sat Nov 14 · 7pm EST"), :full ("Saturday, November 14 · 7pm EST")
  # or :relative ("tonight", "tomorrow", "in 3 days").
  def game_time_tag(starts_at, style:, now: Time.current)
    tag.time(game_time_text(starts_at, style: style, now: now), datetime: starts_at.iso8601, class: "game-time",
      data: { controller: "local-time", action: "turbo:morph@document->local-time#render", local_time_style_value: style, local_time_zone_value: starts_at.time_zone.tzinfo.name })
  end

  def game_time_text(starts_at, style:, now: Time.current)
    days = (starts_at.to_date - now.in_time_zone(starts_at.time_zone).to_date).to_i
    return game_relative(starts_at, days) if style == :relative

    clock = "#{starts_at.min.zero? ? starts_at.strftime("%-l%P") : starts_at.strftime("%-l:%M%P")} #{starts_at.strftime("%Z")}"
    case style
    when :short then "#{game_day(starts_at, days)}, #{clock}"
    when :full then "#{starts_at.strftime("%A, %B %-d")} · #{clock}"
    else "#{starts_at.strftime("%a %b %-d")} · #{clock}"
    end
  end

  # The campaigns list card's line: the next game, or that the next rule date
  # is skipped and when it's back. Nil with no dates, or archived or on hold.
  def next_game_line(campaign, now: Time.current)
    schedule = campaign.schedule
    return unless schedule && campaign.playable?
    dates = schedule.upcoming(limit: 20, from: now)
    return if dates.empty?

    if dates.first.skipped?
      skipped = dates.first
      back = dates.find { !_1.skipped? }
      day = (skipped.starts_at.to_date - now.in_time_zone(schedule.zone).to_date).to_i < 7 ? "this week" : skipped.starts_at.strftime("%a %b %-d")
      tag.span("No game #{day}#{" · back #{back.starts_at.strftime("%b %-d")}" if back}", class: "next-game next-game--skipped", title: skipped.note)
    elsif campaign.current_session && dates.first.played_by?(campaign.current_session)
      tag.span("Playing now", class: "next-game next-game--now")
    else
      tag.span(game_time_tag(dates.first.starts_at, style: :short, now: now), class: "next-game")
    end
  end

  private
    def game_day(starts_at, days)
      if days.zero? then starts_at.hour >= 17 ? "Tonight" : "Today"
      elsif days == 1 then "Tomorrow"
      elsif days.between?(2, 6) then starts_at.strftime("%a")
      else starts_at.strftime("%a %b %-d")
      end
    end

    def game_relative(starts_at, days)
      if days.zero? then starts_at.hour >= 17 ? "tonight" : "today"
      elsif days == 1 then "tomorrow"
      else "in #{days} days"
      end
    end
end
