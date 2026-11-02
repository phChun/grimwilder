# A campaign's game schedule (Campaign::Schedule): a rule (every N weeks, or
# monthly by weekday) whose dates are worked out, never stored ahead, and
# game_dates for the exceptions (a skipped or moved date) and extras.
class CreateCampaignSchedulesAndGameDates < ActiveRecord::Migration[8.2]
  def change
    create_table :campaign_schedules do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :cadence # weekly, monthly, or nil: only dates the GM adds
      t.integer :interval_weeks, null: false, default: 1
      t.integer :weekday, null: false, default: 6
      t.integer :week_of_month # 1–4, or -1 for the last
      t.date :starts_on
      t.string :start_time, null: false, default: "19:00"
      t.string :time_zone, null: false, default: "UTC"
      t.boolean :paused, null: false, default: false
      t.timestamps
    end

    create_table :game_dates do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.date :occurs_on # the rule's date this changes; nil for an extra
      t.datetime :starts_at # a moved or extra date's time
      t.string :status, null: false # skipped, moved, extra (scheduled, later, for RSVPs)
      t.string :note
      t.timestamps
      t.index %i[ campaign_id occurs_on ], unique: true, where: "occurs_on IS NOT NULL"
    end
  end
end
