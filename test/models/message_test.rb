require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @gwen, @pip, @stranger = identities(:gwen), identities(:pip), identities(:stranger)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    # A second player at the table, with no claim on Tibbs.
    @campaign.memberships.create!(identity: @stranger, role: :player)
  end

  def say(identity, kind, **options)
    @campaign.messages.new(identity: identity, kind: kind, body: "Hi", **options)
  end

  test "copies the speaker's name in" do
    assert_equal "Gwen", say(@gwen, "table_talk").tap(&:save!).name
    assert_equal "Gibbletibble \"Tibbs\"", say(@pip, "in_character", character: @tibbs).tap(&:save!).name
    assert_equal "Miller Hode", say(@gwen, "npc", speaker_name: " Miller  Hode ").tap(&:save!).name
  end

  # Who may send each kind: GM, the owning player, another player, a non-member.
  test "the role matrix" do
    matrix = {
      [ "narration", {} ] => { gm: true, owner: false, other: false, outsider: false },
      [ "npc", { speaker_name: "Hode" } ] => { gm: true, owner: false, other: false, outsider: false },
      [ "in_character", { character: characters(:tibbs) } ] => { gm: true, owner: true, other: false, outsider: false },
      [ "table_talk", {} ] => { gm: true, owner: true, other: true, outsider: false },
      [ "whisper", {} ] => { gm: false, owner: true, other: true, outsider: false }
    }
    people = { gm: @gwen, owner: @pip, other: @stranger, outsider: identities(:stranger).dup.tap { _1.update!(email_address: "out@example.com") } }

    matrix.each do |(kind, options), allowed|
      allowed.each do |role, ok|
        assert_equal ok, say(people[role], kind, **options).valid?, "#{role} sending #{kind}"
      end
    end
  end

  test "an NPC line needs a name, and only in-character lines carry a character" do
    assert_not say(@gwen, "npc").valid?
    assert_not say(@pip, "table_talk", character: @tibbs).valid?
    assert_not say(@pip, "in_character").valid?
  end

  test "in character means your active character seated here" do
    @tibbs.update!(status: "fallen")
    assert_not say(@pip, "in_character", character: @tibbs).valid?, "fallen"
    assert_not say(@pip, "in_character", character: characters(:loner)).valid?, "not seated here"
    assert say(@gwen, "in_character", character: @bram).valid?, "the GM's own"
  end

  test "limits a message's length" do
    assert_not say(@pip, "table_talk", body: "x" * (Message::MAX_LENGTH + 1)).valid?
  end

  test "whispers never reach another player through a query" do
    whisper = say(@pip, "whisper").tap(&:save!)
    talk = say(@stranger, "table_talk").tap(&:save!)

    assert_equal [ whisper, talk ], Message.chat_for(@campaign, memberships(:gwen_gm)), "the GM sees every whisper"
    assert_equal [ whisper, talk ], Message.chat_for(@campaign, memberships(:pip_player)), "the sender sees their own"
    assert_equal [ talk ], Message.chat_for(@campaign, @stranger.membership_in(@campaign)), "another player doesn't"
    assert_empty Message.where(kind: "whisper").visible_to(nil), "nor does anyone outside"
  end

  test "whispers go to the GM's stream and the sender's, never the table's" do
    assert_turbo_stream_broadcasts [ @campaign, :gm ], count: 1 do
      assert_turbo_stream_broadcasts [ memberships(:pip_player), :chat ], count: 1 do
        say(@pip, "whisper").save!
      end
    end
    assert_no_turbo_stream_broadcasts [ @campaign, :chat ]
    assert_no_turbo_stream_broadcasts [ @stranger.membership_in(@campaign), :chat ]
  end

  test "everything else goes to the table's stream" do
    assert_turbo_stream_broadcasts [ @campaign, :chat ], count: 1 do
      say(@gwen, "narration").save!
    end
  end

  test "the chat reads oldest first, keeping the newest" do
    3.times { |i| @campaign.messages.create!(identity: @pip, body: "line #{i}") }
    assert_equal [ "line 1", "line 2" ], Message.chat_for(@campaign, memberships(:pip_player), limit: 2).map(&:body)
  end
end
