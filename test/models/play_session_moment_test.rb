require "test_helper"

class PlaySessionMomentTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    PlaySession.start!(@campaign, characters: [ @tibbs, @bram ], by: identities(:gwen)).end!(by: identities(:gwen))
    @session = PlaySession.start!(@campaign, characters: [ @tibbs, @bram ], by: identities(:gwen))
  end

  test "players write moments for their own characters; the GM for anyone" do
    assert PlaySession::Moment.writable_by?(identities(:pip), @tibbs, @campaign)
    assert_not PlaySession::Moment.writable_by?(identities(:pip), @bram, @campaign)
    assert PlaySession::Moment.writable_by?(identities(:gwen), @tibbs, @campaign)
  end

  test "one moment per character per session" do
    @session.moments.create!(character: @tibbs, identity: identities(:pip), text: "Talked the troll down.")
    assert_not @session.moments.build(character: @tibbs, identity: identities(:pip), text: "Again").valid?
    assert_not @session.moments.build(character: @bram, identity: identities(:gwen), text: " ").valid?
  end

  test "the prompt lists present characters you can still write for" do
    assert_equal [ @tibbs ], @session.characters_needing_moments(identities(:pip))
    assert_equal [ @bram, @tibbs ].sort_by(&:name), @session.characters_needing_moments(identities(:gwen))

    @session.moments.create!(character: @tibbs, identity: identities(:pip), text: "Talked the troll down.")
    assert_empty @session.reload.characters_needing_moments(identities(:pip))
    assert_empty @campaign.play_sessions.find_by!(number: 1).characters_needing_moments(identities(:pip)), "no last session before session 1"
  end
end
