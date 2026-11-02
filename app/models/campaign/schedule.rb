# When a campaign plays: a rule (every N weeks on a weekday, or monthly on the
# first to fourth or last weekday), at a time in its own time zone, from a
# first game on. The rule's dates are worked out as needed, in that zone so a
# daylight saving change keeps the wall-clock time; GameDate rows record the
# exceptions (skipped, moved) and extras. With no cadence, only the GM's
# extras are dates; paused keeps the rule and shows nothing.
class Campaign::Schedule < ApplicationRecord
  CADENCES = %w[ weekly monthly ].freeze
  WEEKS_OF_MONTH = [ 1, 2, 3, 4, -1 ].freeze
  INTERVALS = (1..8).freeze
  # A date counts as played when a session started within this of it.
  PLAYED_WITHIN = 12.hours

  # One date to show: a rule date (maybe skipped or moved) or an extra. key
  # names it in routes: the rule date it comes from, or the extra's id.
  Occurrence = Data.define(:starts_at, :occurs_on, :status, :note, :game_date_id) do
    def skipped? = status == "skipped"
    def moved? = status == "moved"
    def extra? = status == "extra"
    def changed? = skipped? || moved?
    def key = occurs_on&.iso8601 || game_date_id.to_s

    def today?(now = Time.current)
      starts_at.to_date == now.in_time_zone(starts_at.time_zone).to_date
    end

    # Today, starting at 5pm or later.
    def tonight?(now = Time.current)
      today?(now) && starts_at.hour >= 17
    end

    def played_by?(session)
      session.present? && (session.started_at - starts_at).abs <= PLAYED_WITHIN
    end
  end

  belongs_to :campaign

  validates :cadence, inclusion: { in: CADENCES }, allow_nil: true
  validates :interval_weeks, inclusion: { in: INTERVALS }
  validates :weekday, inclusion: { in: 0..6 }
  validates :week_of_month, inclusion: { in: WEEKS_OF_MONTH }, if: -> { cadence == "monthly" }
  validates :starts_on, presence: true, if: :cadence
  validates :start_time, format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/, message: "should look like 19:00" }
  validate :time_zone_known

  normalizes :cadence, with: -> { _1.presence }

  after_update :drop_changes_off_the_rule, if: -> { saved_change_to_cadence? || saved_change_to_interval_weeks? || saved_change_to_weekday? || saved_change_to_week_of_month? || saved_change_to_starts_on? }

  def zone
    ActiveSupport::TimeZone[time_zone]
  end

  # The settings form's one "How often" choice: weekly-1 … weekly-8, monthly,
  # or dates (only the dates the GM adds).
  def how_often
    case cadence
    when "weekly" then "weekly-#{interval_weeks}"
    when "monthly" then "monthly"
    else "dates"
    end
  end

  def how_often=(value)
    case value.to_s
    when /\Aweekly-(\d)\z/ then self.cadence, self.interval_weeks = "weekly", $1.to_i
    when "monthly" then self.cadence = "monthly"
    else self.cadence = nil
    end
  end

  # The rule's dates on or after from, in order (an endless Enumerator).
  def rule_dates(from)
    return enum_for(:rule_dates, from) unless block_given?

    case cadence
    when "weekly"
      step = interval_weeks * 7
      date = starts_on + ((weekday - starts_on.wday) % 7)
      date += ((from - date).to_i / step.to_f).ceil * step if from > date
      loop { yield date; date += step }
    when "monthly"
      month = [ starts_on, from ].max.beginning_of_month
      loop do
        date = weekday_in(month)
        yield date if date >= starts_on && date >= from
        month = month.next_month
      end
    end
  end

  def on_rule?(date)
    cadence.present? && rule_dates(date).first == date
  end

  # A date's game time, in the schedule's zone.
  def starts_at_on(date, time = start_time)
    hour, minute = time.split(":").map(&:to_i)
    zone.local(date.year, date.month, date.day, hour, minute)
  end

  # The next dates from now on (a game today stays listed all day), skipped
  # ones included, sorted by time.
  def upcoming(limit: 6, from: Time.current)
    return [] if paused?

    today = from.in_time_zone(zone).to_date
    changes = campaign.game_dates.where.not(occurs_on: nil).index_by(&:occurs_on)
    moved = changes.values.select(&:moved?)
    rule = cadence ? rule_dates(today).first(limit + moved.size).reject { changes[_1]&.moved? } : []

    dates = rule.map { |date| occurrence(date, changes[date]) } +
      moved.select { on_rule?(_1.occurs_on) }.map { occurrence(_1.occurs_on, _1) } +
      campaign.game_dates.extra.map { |extra| Occurrence.new(extra.starts_at.in_time_zone(zone), nil, "extra", extra.note, extra.id) }
    dates.select { _1.starts_at.to_date >= today }.sort_by(&:starts_at).first(limit)
  end

  # The next date that isn't skipped.
  def next_game(from: Time.current)
    upcoming(limit: 20, from: from).find { !_1.skipped? }
  end

  # Skipped and moved rule dates still to come, which a rule change may drop.
  def upcoming_changes
    campaign.game_dates.where(status: %w[ skipped moved ]).where(occurs_on: Time.current.in_time_zone(zone).to_date..)
  end

  # The GM's changes to one date. date is the rule's date (a Date).
  def skip!(date, note: nil)
    change_rule_date!(date, status: "skipped", starts_at: nil, note: note)
  end

  def move!(date, to:, time:, note: nil)
    change_rule_date!(date, status: "moved", starts_at: starts_at_on(to, time), note: note)
  end

  def undo!(date)
    campaign.game_dates.where(occurs_on: date, status: %w[ skipped moved ]).destroy_all
  end

  def add!(date:, time:, note: nil)
    campaign.game_dates.create!(status: "extra", starts_at: starts_at_on(date, time), note: note)
  end

  def move_extra!(extra, to:, time:, note: nil)
    extra.update!(starts_at: starts_at_on(to, time), note: note)
  end

  private
    # The weekday's week_of_month-th day in the month (or its last).
    def weekday_in(month)
      if week_of_month == -1
        last = month.end_of_month
        last - ((last.wday - weekday) % 7)
      else
        month + ((weekday - month.wday) % 7) + (week_of_month - 1) * 7
      end
    end

    def occurrence(date, change)
      starts_at = change&.moved? ? change.starts_at.in_time_zone(zone) : starts_at_on(date)
      Occurrence.new(starts_at, date, change&.status || "scheduled", change&.note, change&.id)
    end

    def change_rule_date!(date, **attributes)
      raise ArgumentError, "#{date.to_fs(:long)} isn't on the schedule." unless on_rule?(date)
      campaign.game_dates.find_or_initialize_by(occurs_on: date).update!(**attributes)
    end

    def drop_changes_off_the_rule
      campaign.game_dates.where(status: %w[ skipped moved ]).find_each { _1.destroy unless on_rule?(_1.occurs_on) }
    end

    def time_zone_known
      errors.add(:time_zone, "isn't one we know") unless time_zone.present? && zone
    end
end
