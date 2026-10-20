require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup { @campaign = campaigns(:bramblewood) }

  test "copies the speaker's name in" do
    assert_equal "Gwen", @campaign.messages.create!(identity: identities(:gwen), body: "Hi").name
    assert_equal "Bram", @campaign.messages.create!(identity: identities(:gwen), character: characters(:bram), body: "Hi").name
  end

  test "speaks only as your own character, seated here" do
    message = @campaign.messages.new(identity: identities(:pip), character: characters(:bram), body: "Hi")
    assert_not message.valid?
    assert message.errors[:character].any?
  end

  test "limits a message's length" do
    assert_not @campaign.messages.new(identity: identities(:pip), body: "x" * (Message::MAX_LENGTH + 1)).valid?
  end

  test "the chat reads oldest first, keeping the newest" do
    3.times { |i| @campaign.messages.create!(identity: identities(:pip), body: "line #{i}") }
    assert_equal [ "line 1", "line 2" ], Message.chat_for(@campaign, limit: 2).map(&:body)
  end
end
