require "test_helper"

class CampaignScheduleTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
  end

  def schedule(**attributes)
    @campaign.create_schedule!({ cadence: "weekly", weekday: 6, starts_on: Date.new(2026, 10, 3), start_time: "19:00", time_zone: "America/New_York" }.merge(attributes))
  end

  def days(dates) = dates.map { _1.starts_at.to_date }

  test "every week, from the first game on" do
    weekly = schedule
    travel_to Time.utc(2026, 10, 14, 12) do
      assert_equal %w[ 2026-10-17 2026-10-24 2026-10-31 ], days(weekly.upcoming(limit: 3)).map(&:iso8601)
    end
  end

  test "every other week counts from the anchor, and the first game day can be any day before it" do
    fortnightly = schedule(interval_weeks: 2, starts_on: Date.new(2026, 10, 1)) # a Thursday: the first Saturday is Oct 3
    assert_equal [ Date.new(2026, 10, 3), Date.new(2026, 10, 17), Date.new(2026, 10, 31), Date.new(2026, 11, 14) ], fortnightly.rule_dates(Date.new(2026, 9, 1)).first(4)
    assert_equal [ Date.new(2026, 10, 31), Date.new(2026, 11, 14) ], fortnightly.rule_dates(Date.new(2026, 10, 18)).first(2)
    assert fortnightly.on_rule?(Date.new(2026, 11, 14))
    assert_not fortnightly.on_rule?(Date.new(2026, 11, 7))
  end

  test "monthly on the first Saturday and on the last Friday" do
    first = schedule(cadence: "monthly", week_of_month: 1)
    assert_equal [ Date.new(2026, 10, 3), Date.new(2026, 11, 7), Date.new(2026, 12, 5) ], first.rule_dates(Date.new(2026, 10, 1)).first(3)

    first.update!(week_of_month: -1, weekday: 5)
    assert_equal [ Date.new(2026, 10, 30), Date.new(2026, 11, 27), Date.new(2026, 12, 25), Date.new(2027, 1, 29) ], first.rule_dates(Date.new(2026, 10, 1)).first(4)
  end

  test "the game stays at 7pm local across daylight saving's end" do
    weekly = schedule
    travel_to Time.utc(2026, 10, 30, 12) do
      before, after = weekly.upcoming(limit: 2)
      assert_equal [ 19, 19 ], [ before.starts_at.hour, after.starts_at.hour ]
      assert_equal [ "EDT", "EST" ], [ before.starts_at.zone, after.starts_at.zone ]
      assert_equal Time.utc(2026, 10, 31, 23), before.starts_at
      assert_equal Time.utc(2026, 11, 8, 0), after.starts_at
    end
  end

  test "skip, move, add an extra and undo" do
    weekly = schedule
    travel_to Time.utc(2026, 11, 2, 12) do
      weekly.skip!(Date.new(2026, 11, 7), note: "Gwen's away")
      weekly.move!(Date.new(2026, 11, 14), to: Date.new(2026, 11, 13), time: "18:30")
      weekly.add!(date: Date.new(2026, 11, 10), time: "20:00", note: "Bonus")

      dates = weekly.upcoming(limit: 5)
      assert_equal %w[ skipped extra moved scheduled scheduled ], dates.map(&:status)
      assert_equal "Gwen's away", dates.first.note
      assert_equal Time.utc(2026, 11, 13, 23, 30), dates.third.starts_at
      assert_equal Date.new(2026, 11, 14), dates.third.occurs_on
      assert_equal "extra", weekly.next_game.status

      assert_raises(ArgumentError) { weekly.skip!(Date.new(2026, 11, 8)) }
      weekly.undo!(Date.new(2026, 11, 7))
      assert_equal "scheduled", weekly.upcoming(limit: 1).first.status
    end
  end

  test "a date moved later than the next rule dates still shows in order, and a moved past date is gone" do
    weekly = schedule
    travel_to Time.utc(2026, 11, 2, 12) do
      weekly.move!(Date.new(2026, 11, 7), to: Date.new(2026, 11, 22), time: "19:00")
      assert_equal %w[ 2026-11-14 2026-11-21 2026-11-22 2026-11-28 ], days(weekly.upcoming(limit: 4)).map(&:iso8601)
    end
  end

  test "changing the rule drops skipped and moved dates no longer on it" do
    weekly = schedule
    travel_to Time.utc(2026, 11, 2, 12) do
      weekly.skip!(Date.new(2026, 11, 7))
      weekly.skip!(Date.new(2026, 11, 14))
      weekly.add!(date: Date.new(2026, 11, 10), time: "19:00")

      weekly.update!(how_often: "weekly-2")
      assert_equal [ Date.new(2026, 11, 14) ], @campaign.game_dates.skipped.pluck(:occurs_on)
      assert_equal 1, @campaign.game_dates.extra.count

      weekly.update!(how_often: "dates")
      assert_empty @campaign.game_dates.skipped
      assert_equal %w[ extra ], weekly.upcoming.map(&:status)
    end
  end

  test "paused shows nothing, and how_often reads back what was set" do
    weekly = schedule(paused: true)
    assert_empty weekly.upcoming
    assert_nil weekly.next_game
    assert_equal "weekly-1", weekly.how_often
    weekly.how_often = "monthly"
    assert_equal "monthly", weekly.how_often
    assert_not weekly.update(time_zone: "Mars/Olympus_Mons")
  end
end
