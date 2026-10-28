require "test_helper"

# The table rail: chat and log in one stream, the composer's speak-as picker,
# whispers to the GM and the filters.
class ChatTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "a player speaks in character, as themselves, or to the GM, live" do
    sign_in_as identities(:pip)

    assert_turbo_stream_broadcasts [ @campaign, :chat ], count: 2 do
      post campaign_messages_path(@campaign), params: { speak_as: "character:#{characters(:tibbs).id}", body: "Ash, hold the door." }, as: :turbo_stream
      assert_response :no_content
      post campaign_messages_path(@campaign), params: { speak_as: "table_talk", body: "brb" }, as: :turbo_stream
    end
    post campaign_messages_path(@campaign), params: { speak_as: "whisper", body: "Does Tibbs know the miller?" }, as: :turbo_stream

    assert_equal [ %w[ in_character Gibbletibble\ "Tibbs" ], %w[ table_talk Pip ], %w[ whisper Pip ] ], @campaign.messages.order(:id).map { [ _1.kind, _1.name ] }
  end

  test "the GM narrates, voices NPCs and talks; a player can't narrate, voice an NPC or speak as someone else's character" do
    sign_in_as identities(:gwen)
    post campaign_messages_path(@campaign), params: { speak_as: "narration", body: "Smoke pours through the slats." }
    post campaign_messages_path(@campaign), params: { speak_as: "npc", speaker_name: "Miller Hode", body: "Leave the sacks!" }
    assert_equal %w[ narration npc ], @campaign.messages.order(:id).pluck(:kind)

    sign_out
    sign_in_as identities(:pip)
    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { speak_as: "narration", body: "I narrate now" }, as: :turbo_stream
      assert_response :unprocessable_entity
      post campaign_messages_path(@campaign), params: { speak_as: "npc", speaker_name: "Hode", body: "Hi" }, as: :turbo_stream
      post campaign_messages_path(@campaign), params: { speak_as: "character:#{characters(:bram).id}", body: "As Bram" }, as: :turbo_stream
    end
  end

  test "speak-as is a dropdown of the player's characters, table talk and a whisper to the GM" do
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_equal [ "As Tibbs", "Table talk", "To GM" ], css_select(".composer select[name=speak_as] option").map(&:text)

    identities(:pip).characters.create!(name: "Moss", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign)
    get campaign_path(@campaign)
    assert_select ".composer select[name=speak_as] option", 4
  end

    test "a blank message isn't sent, and outsiders can't post" do
    sign_in_as identities(:pip)
    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { speak_as: "table_talk", body: "   " }
    end

    sign_out
    sign_in_as identities(:stranger)
    post campaign_messages_path(@campaign), params: { speak_as: "table_talk", body: "Hello?" }
    assert_response :not_found
  end

  test "the rail merges chat and log in time order, with the speak-as picker for each role" do
    @campaign.messages.create!(identity: identities(:gwen), kind: "narration", body: "Smoke pours through the slats.", created_at: 2.minutes.ago)
    roll = characters(:tibbs).roll!("agility", by: identities(:pip))
    roll.update_columns(created_at: 1.minute.ago)
    @campaign.messages.create!(identity: identities(:pip), body: "oof")

    sign_in_as identities(:pip)
    get character_path(characters(:tibbs))
    assert_select ".table-rail #table_feed > li", 3
    assert_select "#table_feed > li:nth-child(1).chat-line--narration .chat-line__label", /GM · Cut to/
    assert_select "#table_feed > li:nth-child(2)##{dom_id(roll)}.feed-item--dice"
    assert_select "#table_feed > li:nth-child(3).feed-item--talk .chat-line__body", "oof"
    assert_select ".feed__filter input[type=radio]", 3
    assert_select ".composer select[name=speak_as] option", 3
    assert_select ".composer select[name=speak_as] option[value=?][selected]", "character:#{characters(:tibbs).id}"
    assert_select ".composer select[name=speak_as] option[value=whisper]", "To GM"
    assert_select ".table-rail__head .suspense-meter"

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".composer select[name=speak_as] option", 3
    assert_select ".composer select[name=speak_as] option[value=table_talk][selected]", 1, "between sessions the GM starts on table talk"
    assert_select ".composer select[name=speak_as] option[value=narration]", "Narrate"
    assert_select ".composer select[name=speak_as] option[value=npc]", "As NPC"
    assert_select ".composer input[name=speaker_name]"
    assert_select ".composer select[name=speak_as] option[value=whisper]", 0
  end

  test "the rail can keep your place: a scroller, a hidden new-lines pill, and who made each line" do
    note = Roll.note!(campaign: @campaign, by: identities(:gwen), text: "The mill burns.")
    sign_in_as identities(:pip)
    get campaign_path(@campaign)

    assert_select ".table-rail[data-controller~=feed] .feed__scroller[data-feed-target=scroller]"
    assert_select ".table-rail button.feed__new[hidden][data-action='feed#latest']"
    assert_select "##{dom_id(note)}[data-identity=?]", identities(:gwen).id.to_s
  end

  test "the faces atop the rail are marked for presence_controller.js to halo" do
    sign_in_as identities(:pip)
    get campaign_path(@campaign)

    assert_select ".table-rail[data-controller~=presence][data-presence-campaign-value=?]", @campaign.id.to_s
    assert_select ".table-rail__head .avatars[role=group] .avatar", 2
    assert_select ".avatar.avatar--gm[role=img][aria-label=?][data-label=?][data-presence-identity=?][data-presence-name=?]", identities(:gwen).display_name, identities(:gwen).display_name, identities(:gwen).id.to_s, identities(:gwen).display_name
    assert_select ".avatar:not(.avatar--gm)[data-presence-identity=?]", identities(:pip).id.to_s
  end

  test "whispers never reach another player's page" do
    @campaign.memberships.create!(identity: identities(:stranger), role: :player)
    @campaign.messages.create!(identity: identities(:pip), kind: "whisper", body: "Secret plan")

    sign_in_as identities(:stranger)
    get campaign_path(@campaign)
    assert_no_match "Secret plan", response.body

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".chat-line--whisper .chat-line__label", /only you and the GM/
    assert_select ".chat-line--whisper .chat-line__body", "Secret plan"

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".chat-line--whisper .chat-line__body", "Secret plan"
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", Turbo::StreamsChannel.signed_stream_name([ @campaign, :gm ])
  end

  test "an unseated character's sheet has no table rail" do
    sign_in_as identities(:stranger)

    get character_path(characters(:loner))
    assert_select ".play-view--solo", 1
    assert_select ".table-rail", 0
  end

  test "the GM deletes a line, for everyone; nobody else can" do
    line = @campaign.messages.create!(identity: identities(:pip), name: "Pip", kind: "table_talk", body: "oops, wrong window")

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".table-rail", 1
    assert_select ".table-rail--gm", 0, "the delete buttons stay hidden"

    assert_no_difference -> { Message.count } do
      delete campaign_message_path(@campaign, line), as: :turbo_stream
    end
    assert_response :forbidden
  end

  test "the GM's rail shows the delete buttons, and deleting broadcasts the removal" do
    line = @campaign.messages.create!(identity: identities(:pip), name: "Pip", kind: "table_talk", body: "oops, wrong window")
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".table-rail--gm ##{dom_id(line)} form.chat-line__delete-form[action=?] button[aria-label=?]", campaign_message_path(@campaign, line), "Delete this line"

    assert_turbo_stream_broadcasts [ @campaign, :chat ] do
      delete campaign_message_path(@campaign, line), as: :turbo_stream
    end
    assert_response :no_content
    assert_not Message.exists?(line.id)
  end
end
