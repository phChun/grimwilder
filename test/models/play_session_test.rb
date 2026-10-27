require "test_helper"

class PlaySessionTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "session 1 resets thread (2, +1 from Mastermind), but gives no spark or suspense" do
    @tibbs.update!(thread: 0)

    session = PlaySession.start!(@campaign, characters: [ @tibbs ], recap: "ignored on session 1", by: identities(:gwen))
    assert_equal [ 1, nil ], [ session.number, session.recap ]
    assert_equal [ 3, 1 ], [ @tibbs.reload.thread, @tibbs.spark ]
    assert_equal 0, @campaign.reload.suspense
    assert_equal [ @tibbs ], session.characters
  end

  test "later sessions give spark to everyone here, and the GM suspense" do
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen)).end!(by: identities(:gwen))
    @tibbs.update!(thread: 0)

    session = PlaySession.start!(@campaign, characters: [ @tibbs, @bram ], recap: "The bridge burned.", by: identities(:gwen))
    assert_equal [ 2, "The bridge burned." ], [ session.number, session.recap ]
    assert_equal [ 3, 2 ], [ @tibbs.reload.thread, @tibbs.spark ], "Mastermind: +1 thread"
    assert_equal 2, @bram.reload.spark, "already at the cap"
    assert_equal 1, @campaign.reload.suspense
  end

  test "characters who aren't here are left alone" do
    PlaySession.start!(@campaign, characters: [], by: identities(:gwen)).end!(by: identities(:gwen))
    @tibbs.update!(thread: 0)

    PlaySession.start!(@campaign, characters: [ @bram ], by: identities(:gwen))
    assert_equal [ 0, 1 ], [ @tibbs.reload.thread, @tibbs.spark ]
  end

  test "one session at a time, for seated characters only" do
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))

    assert_raises(ArgumentError) { PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen)) }
    assert_not @campaign.play_sessions.new(number: 9, started_at: Time.current).valid?

    other = Campaign.create_with_gm!(name: "Elsewhere", gm: Identity.create!(email_address: "elsewhere@example.com", name: "Elsie"))
    assert_raises(ArgumentError) { PlaySession.start!(other, characters: [ @tibbs ], by: identities(:gwen)) }
  end

  test "starting and ending post markers, and rolls in between are stamped" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], recap: nil, by: identities(:gwen))
    roll = @tibbs.roll!("wits", by: identities(:pip))
    session.end!(by: identities(:gwen), notes: "Into the Mire next.")
    after = @tibbs.roll!("wits", by: identities(:pip))

    markers = @campaign.rolls.marker.order(:id)
    assert_equal [ "Session 1 begins", "Session 1 ends" ], markers.map(&:name)
    assert_equal "Into the Mire next.", markers.last.question
    assert_equal session, roll.play_session
    assert_nil after.play_session, "between sessions"
  end

  test "ending gives everyone here 1 XP, or 2 for a standout session" do
    session = PlaySession.start!(@campaign, characters: [ @tibbs, @bram ], by: identities(:gwen))
    session.end!(by: identities(:gwen))
    assert_equal [ 1, 1 ], [ @tibbs.reload.xp, @bram.reload.xp ]

    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: identities(:gwen))
    levelled = session.end!(by: identities(:gwen), standout: true)
    assert_equal [ 2, 1 ], [ @tibbs.reload.level, @tibbs.xp ], "the first of the 2 XP fills level 1's 2 boxes; the second carries over"
    assert_equal [ @tibbs ], levelled
    assert_equal [ { "character_id" => @tibbs.id, "name" => @tibbs.name, "level" => 2 } ], @campaign.rolls.marker.last.sides
    assert session.standout?
    assert_raises(ArgumentError) { session.end!(by: identities(:gwen)) }
  end
end
