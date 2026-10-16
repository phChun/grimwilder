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
    assert_select "turbo-cable-stream-source", 1

    sign_out
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)
    assert_select "#roll_log > li", 1
    assert_select "turbo-cable-stream-source", 2
  end

  test "a disaster shows the spark it gave" do
    characters(:tibbs).roll!("brawn", by: identities(:pip), thorns: 1, random: FixedDice.new([ 2, 8 ]))

    sign_in_as identities(:gwen)
    get campaign_path(@campaign)
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

  test "unseated characters roll without a log" do
    perform_enqueued_jobs do
      assert_no_turbo_stream_broadcasts [ @campaign, :rolls ] do
        characters(:loner).roll!("agility", by: identities(:stranger))
      end
    end
  end
end
