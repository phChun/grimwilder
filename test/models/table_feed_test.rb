require "test_helper"

class TableFeedTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
  end

  test "a page is the newest lines of either kind, oldest first, and says where the next one starts" do
    old_roll = Roll.note!(campaign: @campaign, by: identities(:gwen), text: "Long ago").tap { _1.update_columns(created_at: 3.hours.ago) }
    talk = @campaign.messages.create!(identity: identities(:pip), kind: "table_talk", body: "Hi", created_at: 2.hours.ago)
    new_roll = Roll.note!(campaign: @campaign, by: identities(:gwen), text: "Just now").tap { _1.update_columns(created_at: 1.hour.ago) }

    feed = TableFeed.new(@campaign, memberships(:pip_player))
    assert_equal [ old_roll, talk, new_roll ], feed.entries
    assert_not feed.more?
    assert_equal old_roll.created_at, feed.oldest_at

    earlier = TableFeed.new(@campaign, memberships(:pip_player), before: talk.created_at)
    assert_equal [ old_roll ], earlier.entries
  end

  test "pages back through a mix without skipping or repeating" do
    times = (1..(TableFeed::PAGE * 2 + 3)).map { |n| n.minutes.ago }
    times.each_with_index do |at, index|
      if index.even?
        @campaign.messages.create!(identity: identities(:pip), kind: "table_talk", body: "m#{index}", created_at: at)
      else
        Roll.note!(campaign: @campaign, by: identities(:gwen), text: "r#{index}").update_columns(created_at: at)
      end
    end

    seen = []
    feed = TableFeed.new(@campaign, memberships(:gwen_gm))
    loop do
      seen = feed.entries + seen
      break unless feed.more?
      feed = TableFeed.new(@campaign, memberships(:gwen_gm), before: feed.oldest_at)
    end

    assert_equal times.size, seen.size
    assert_equal seen.uniq.size, seen.size
    assert_equal seen.map(&:created_at), seen.map(&:created_at).sort
  end

  test "scrolling back shows a player only what they may see" do
    gm_only = Roll.note!(campaign: @campaign, by: identities(:gwen), text: "Secret").tap { _1.update_columns(created_at: 2.hours.ago, gm_only: true) }

    assert_not_includes TableFeed.new(@campaign, memberships(:pip_player), before: 1.hour.ago).entries, gm_only
    assert_includes TableFeed.new(@campaign, memberships(:gwen_gm), before: 1.hour.ago).entries, gm_only
  end
end
