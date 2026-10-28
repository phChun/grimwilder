require "test_helper"

class TableLogTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "the table sees character and pool rolls in the order they happened" do
    characters(:tibbs).roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 2 ]))
    pools(:lookouts).roll!(by: identities(:gwen), random: FixedDice.new([ 1, 2, 4, 5, 6, 6 ]))

    sign_in_as identities(:pip)
    get campaign_path(@campaign)

    assert_select "#table_feed > li", 2
    assert_select "#table_feed > li:first-child .roll-result__word", "Critical"
    assert_select "#table_feed > li:last-child.feed-pool", /Lookouts spot you.*6d → 4d.*Rolled 6d: 2d dropped\. 4d left\./m
  end

  test "a player doesn't see rolls on hidden pools; the GM does" do
    pools(:ambush).roll!(by: identities(:gwen))

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#table_feed > li", 0
    assert_select "turbo-cable-stream-source", 7, "pool and table refreshes, the live banner, the open log, your own secret rolls, the chat and your own whispers"

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#table_feed > li", 1
    assert_select "turbo-cable-stream-source", 7, "pool and table refreshes, the live banner, both logs, the chat and the GM's stream"
  end

  test "the rail shows the newest #{TableFeed::PAGE} lines, and scrolling back loads the rest" do
    (TableFeed::PAGE + 2).times { |n| characters(:tibbs).roll!("wits", by: identities(:pip)).update_columns(created_at: (200 - n).minutes.ago) }
    5.times { |n| @campaign.messages.create!(identity: identities(:pip), kind: "table_talk", body: "line #{n}", created_at: (100 - n).minutes.ago) }

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#table_feed > li", TableFeed::PAGE
    rail = css_select(".table-rail[data-controller~=feed]").first
    assert_equal "true", rail["data-feed-more-value"]
    assert_equal campaign_feed_path(@campaign), rail["data-feed-older-url-value"]
    assert_select ".feed__scroller .feed__older[data-feed-target=older]"

    get campaign_feed_path(@campaign, before: rail["data-feed-before-value"])
    assert_response :success
    assert_select "[data-feed-page][data-more=false] > li", 7, "the two rolls and five lines before the page, none skipped"
    assert_select "[data-feed-page] > li.feed-item--dice", 7

    get campaign_feed_path(@campaign, before: "not a time")
    assert_response :bad_request
  end

  test "outsiders can't scroll back through a table" do
    sign_in_as identities(:stranger)
    get campaign_feed_path(@campaign, before: Time.current.iso8601(6))
    assert_response :not_found
  end

  test "a disaster shows the spark it gave" do
    characters(:tibbs).roll!("brawn", by: identities(:pip), thorns: 1, random: FixedDice.new([ 2, 8 ]))

    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".feed-item--disaster", /Disaster: Gibbletibble "Tibbs" takes spark\./
  end

  test "new rolls reach the table live" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :rolls ], count: 1 do
        characters(:tibbs).roll!("wits", by: identities(:pip))
      end
    end
    assert_no_turbo_stream_broadcasts [ @campaign, :gm_rolls ]
  end

  test "rolls on hidden pools only reach the GM" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :gm_rolls ], count: 1 do
        pools(:ambush).roll!(by: identities(:gwen))
      end
    end
    assert_no_turbo_stream_broadcasts [ @campaign, :rolls ]
  end

  test "a player can keep a roll for the GM: only the GM and they see it" do
    @campaign.memberships.create!(identity: identities(:ada), role: "player")

    sign_in_as identities(:pip)
    get character_path(characters(:tibbs))
    assert_select "dialog.roll-dialog input[type=checkbox][name=gm_only]", 4, "one in each stat's setup"

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :gm_rolls ], count: 1 do
        assert_turbo_stream_broadcasts [ memberships(:pip_player), :rolls ], count: 1 do
          post character_rolls_path(characters(:tibbs)), params: { stat: "wits", gm_only: "1" }
        end
      end
    end
    assert_no_turbo_stream_broadcasts [ @campaign, :rolls ]
    assert @campaign.rolls.sole.gm_only?

    get campaign_path(@campaign)
    assert_select "#table_feed > li", 1
    assert_select "#table_feed .tag", "GM only"

    sign_out
    sign_in_as identities(:ada)
    get campaign_path(@campaign)
    assert_select "#table_feed > li", 0

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#table_feed > li", 1
  end

  test "a character at no table has no one to keep a roll from" do
    tibbs = characters(:tibbs)
    tibbs.update!(campaign: nil)
    assert_raises(ArgumentError) { tibbs.roll!("wits", by: identities(:pip), gm_only: true) }
  end

  test "taking spark from a critical updates the log entry live" do
    tibbs = characters(:tibbs)
    roll = tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 2 ]))

    sign_in_as identities(:pip)
    get character_path(tibbs)
    assert_select "form[action=?] button", character_roll_critical_spark_path(tibbs, roll), text: "Nothing fits: take spark"

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :rolls ], count: 1 do
        post character_roll_critical_spark_path(tibbs, roll)
      end
    end
    assert_redirected_to character_path(tibbs)
    assert_equal 2, tibbs.reload.spark

    follow_redirect!
    assert_select "form[action=?]", character_roll_critical_spark_path(tibbs, roll), count: 0
    assert_select "#roll-toast .roll-toast__note--spark", "Critical: nothing fit, so Gibbletibble \"Tibbs\" takes spark."

    post character_roll_critical_spark_path(tibbs, roll)
    assert_equal 2, tibbs.reload.spark
    assert flash[:alert].present?
  end

  test "only the owner takes spark for a critical" do
    roll = characters(:tibbs).roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 2 ]))

    sign_in_as identities(:gwen)
    post character_roll_critical_spark_path(characters(:tibbs), roll)
    assert_response :not_found
    assert_equal 1, characters(:tibbs).reload.spark
  end

  test "unseated characters roll without a log" do
    perform_enqueued_jobs do
      assert_no_turbo_stream_broadcasts [ @campaign, :rolls ] do
        characters(:loner).roll!("agility", by: identities(:stranger))
      end
    end
  end
end
