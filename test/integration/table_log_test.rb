require "test_helper"

class TableLogTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "the table sees character and pool rolls, newest first" do
    characters(:tibbs).roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 2 ]))
    pools(:lookouts).roll!(by: identities(:gwen), random: FixedDice.new([ 1, 2, 4, 5, 6, 6 ]))

    sign_in_as identities(:pip)
    get campaign_path(@campaign)

    assert_select "#roll_log > li", 2
    assert_select "#roll_log > li:first-child", /Lookouts spot you.*Rolled 6d: 2d dropped\. 4d left\./m
    assert_select "#roll_log > li:last-child .log-entry__result", "Perfect · critical"
  end

  test "a player doesn't see rolls on hidden pools; the GM does" do
    pools(:ambush).roll!(by: identities(:gwen))

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#roll_log > li", 0
    assert_select "turbo-cable-stream-source", 5, "pool and table refreshes, the open log, the chat and the live banner"

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#roll_log > li", 1
    assert_select "turbo-cable-stream-source", 6, "pool and table refreshes, both logs, the chat and the live banner"
  end

  test "the table shows the newest #{CampaignTable::LOG_SIZE} log entries" do
    (CampaignTable::LOG_SIZE + 2).times { characters(:tibbs).roll!("wits", by: identities(:pip)) }

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#roll_log > li", CampaignTable::LOG_SIZE
  end

  test "a disaster shows the spark it gave" do
    characters(:tibbs).roll!("brawn", by: identities(:pip), thorns: 1, random: FixedDice.new([ 2, 8 ]))

    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".log-entry--disaster", /Disaster: Gibbletibble "Tibbs" takes spark\./
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
    assert_select "#last-roll .last-roll__note--spark", "Critical: nothing fit, so Gibbletibble \"Tibbs\" takes spark."

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
