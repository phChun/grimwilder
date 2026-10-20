require "test_helper"

class ChatTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "a player chats as themselves or as their own character, live" do
    sign_in_as identities(:pip)

    assert_turbo_stream_broadcasts [ @campaign, :chat ], count: 2 do
      post campaign_messages_path(@campaign), params: { body: "  brb, snacks  " }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :no_content
      post campaign_messages_path(@campaign), params: { body: "I'll pick the lock.", character_id: characters(:tibbs).id }
      assert_redirected_to campaign_path(@campaign)
    end

    ooc, in_character = @campaign.messages.order(:id).last(2)
    assert_equal [ "Pip", "brb, snacks", nil ], [ ooc.name, ooc.body, ooc.character ]
    assert_equal [ characters(:tibbs).name, characters(:tibbs) ], [ in_character.name, in_character.character ]
  end

  test "nobody speaks as someone else's character" do
    sign_in_as identities(:pip)

    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { body: "Charge!", character_id: characters(:bram).id }
    end
    assert_response :not_found
  end

  test "a blank message isn't sent" do
    sign_in_as identities(:pip)

    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { body: "   " }
    end
    assert flash[:alert].present?
  end

  test "outsiders can't post" do
    sign_in_as identities(:stranger)

    post campaign_messages_path(@campaign), params: { body: "hello?" }
    assert_response :not_found
  end

  test "the chat shows on the GM table and on a seated character's sheet" do
    @campaign.messages.create!(identity: identities(:gwen), body: "Welcome to Bramblewood.")

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#chat #chat_messages .chat-line__body", "Welcome to Bramblewood."
    assert_select "#chat select[name=character_id] option", 2, "yourself, or Tibbs"

    get character_path(characters(:tibbs))
    assert_select ".play-view__rail #chat_messages .chat-line__body", "Welcome to Bramblewood."
    assert_select ".play-view__rail select[name=character_id] option[selected]", characters(:tibbs).name
    assert_select ".play-view__rail #roll_log", 1
  end

  test "an unseated character's sheet has no table rail" do
    sign_in_as identities(:stranger)

    get character_path(characters(:loner))
    assert_select ".play-view--solo", 1
    assert_select ".play-view__rail", 0
  end
end
