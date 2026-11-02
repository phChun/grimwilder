require "test_helper"

# Schedules (Campaign::Schedule): the GM sets one in settings and changes
# dates from Coming up; everyone sees the next game on the list, the campaign
# page and (between sessions) the GM table.
class SchedulesTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
  end

  def weekly!
    @campaign.create_schedule!(cadence: "weekly", weekday: 6, starts_on: Date.new(2026, 10, 3), start_time: "19:00", time_zone: "America/New_York")
  end

  test "the GM sets a schedule in settings" do
    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "#settings-schedule select[name=?][data-time-zone-fill-value=true]", "schedule[time_zone]"

    patch campaign_schedule_path(@campaign), params: { schedule: { how_often: "weekly-2", weekday: 5, starts_on: "2026-11-06", start_time: "19:30", time_zone: "America/Chicago", paused: "0" } }
    assert_redirected_to edit_campaign_path(@campaign, anchor: "settings-schedule")
    schedule = @campaign.reload.schedule
    assert_equal [ "weekly", 2, 5, "19:30", "America/Chicago" ], [ schedule.cadence, schedule.interval_weeks, schedule.weekday, schedule.start_time, schedule.time_zone ]

    patch campaign_schedule_path(@campaign), params: { schedule: { how_often: "weekly-1", start_time: "7pm" } }
    assert_match(/Start time should look like 19:00/, flash[:alert])
  end

  test "the list card says tonight, or that this week's is skipped and when it's back" do
    weekly!
    travel_to Time.utc(2026, 11, 7, 15) do
      sign_in_as identities(:gwen)
      get campaigns_path
      assert_select ".campaign-card .next-game time[datetime=?][data-local-time-zone-value=?]", "2026-11-07T19:00:00-05:00", "America/New_York", "Tonight, 7pm EST"

      @campaign.schedule.skip!(Date.new(2026, 11, 7), note: "Gwen's away")
      get campaigns_path
      assert_select ".campaign-card .next-game--skipped[title=?]", "Gwen's away", "No game this week · back Nov 14"
    end
    travel_to Time.utc(2026, 11, 9, 15) do
      sign_in_as identities(:gwen)
      get campaigns_path
      assert_select ".campaign-card .next-game time", "Sat, 7pm EST"
    end
  end

  test "the campaign page shows the next game and what's coming up; only the GM gets the menus" do
    weekly!
    travel_to Time.utc(2026, 11, 2, 15) do
      @campaign.schedule.skip!(Date.new(2026, 11, 7), note: "Gwen's away")
      @campaign.schedule.move!(Date.new(2026, 11, 14), to: Date.new(2026, 11, 13), time: "19:00")

      sign_in_as identities(:pip)
      get campaign_path(@campaign)
      assert_select ".campaign-hero__next dd", /Friday, November 13 · 7pm EST\s+\(in 11 days\)/
      assert_select "#coming-up .coming-up__date--skipped", /Sat Nov 7 · 7pm EST\s+Skipped\s+Gwen's away/
      assert_select "#coming-up .coming-up__date", /moved from Sat Nov 14/
      assert_select "#coming-up .coming-up__more", 0

      patch campaign_game_date_path(@campaign, "2026-11-21"), params: { change: "skip" }
      assert_response :forbidden
      sign_out

      sign_in_as identities(:gwen)
      get campaign_path(@campaign)
      assert_select "#coming-up-2026-11-07 form[action=?] button", campaign_game_date_path(@campaign, "2026-11-07"), "Undo skip"
      assert_select "#coming-up-2026-11-21 input[type=submit][value=?]", "Skip this date"
      assert_select "#coming-up-add form[action=?]", campaign_game_dates_path(@campaign)

      patch campaign_game_date_path(@campaign, "2026-11-21"), params: { change: "skip", note: "Holiday" }
      assert @campaign.game_dates.skipped.exists?(occurs_on: Date.new(2026, 11, 21), note: "Holiday")
      delete campaign_game_date_path(@campaign, "2026-11-07")
      assert_not @campaign.game_dates.exists?(occurs_on: Date.new(2026, 11, 7))

      post campaign_game_dates_path(@campaign), params: { date: "2026-11-10", time: "20:00" }
      extra = @campaign.game_dates.extra.sole
      patch campaign_game_date_path(@campaign, extra.id), params: { change: "move", date: "2026-11-11", time: "20:00" }
      assert_equal Time.utc(2026, 11, 12, 1), extra.reload.starts_at
      delete campaign_game_date_path(@campaign, extra.id)
      assert_empty @campaign.game_dates.extra
    end
  end

  test "the GM table's session bar names the next game between sessions" do
    weekly!
    travel_to Time.utc(2026, 11, 3, 15) do
      sign_in_as identities(:gwen)
      get campaign_table_path(@campaign)
      assert_select ".scene-bar__status", /Between sessions · next game\s+Sat, 7pm EST/
      assert_select ".gm-view__side #coming-up"
    end
  end

  test "archived or on hold, no dates show" do
    weekly!
    @campaign.update!(archived_at: Time.current)
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#coming-up", 0
    assert_select ".campaign-hero__next", 0
    get campaigns_path
    assert_select ".next-game", 0
  end

  test "on hold, no dates show either" do
    weekly!
    identities(:gwen).update!(plan: "tester")
    @campaign.update_columns(created_at: 1.month.ago)
    Campaign.create_with_gm!(name: "Saltmarsh", gm: identities(:gwen))
    identities(:gwen).apply_plan!("free")
    assert @campaign.reload.on_hold?

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#coming-up", 0
    get campaigns_path
    assert_select ".next-game", 0
  end

  test "settings warn before a rule change drops skipped dates" do
    weekly!
    travel_to Time.utc(2026, 11, 2, 15) do
      @campaign.schedule.skip!(Date.new(2026, 11, 7))
      sign_in_as identities(:gwen)
      get edit_campaign_path(@campaign)
      assert_select "#settings-schedule form[data-turbo-confirm^=?]", "1 skipped or moved date still to come."
    end
  end
end
