require "test_helper"

# The table rail: chat and log in one stream, the Show choice that also says
# where the composer sends, whispers and the filters.
class ChatTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "a player speaks in character from the story views, as themselves from Table talk, and to the GM from their conversation, live" do
    sign_in_as identities(:pip)

    assert_turbo_stream_broadcasts [ @campaign, :chat ], count: 2 do
      post campaign_messages_path(@campaign), params: { context: "all", body: "Ash, hold the door." }, as: :turbo_stream
      assert_response :no_content
      post campaign_messages_path(@campaign), params: { context: "talk", body: "brb" }, as: :turbo_stream
    end
    post campaign_messages_path(@campaign), params: { context: "private-gm", body: "Does Tibbs know the miller?" }, as: :turbo_stream

    assert_equal [ %w[ in_character Gibbletibble\ "Tibbs" ], %w[ table_talk Pip ], %w[ whisper Pip ] ], @campaign.messages.order(:id).map { [ _1.kind, _1.name ] }
  end

  test "the GM narrates or voices an NPC from the story views; a player can't, nor speak as someone else's character" do
    sign_in_as identities(:gwen)
    post campaign_messages_path(@campaign), params: { context: "story", body: "Smoke pours through the slats." }
    post campaign_messages_path(@campaign), params: { context: "story", voice: "npc", speaker_name: "Miller Hode", body: "Leave the sacks!" }
    post campaign_messages_path(@campaign), params: { context: "talk", voice: "npc", body: "Pizza's here" }
    assert_equal %w[ narration npc table_talk ], @campaign.messages.order(:id).pluck(:kind)

    sign_out
    sign_in_as identities(:pip)
    post campaign_messages_path(@campaign), params: { context: "story", voice: "npc", speaker_name: "Hode", character_id: characters(:bram).id, body: "As Bram" }, as: :turbo_stream
    assert_equal [ "in_character", characters(:tibbs) ], [ @campaign.messages.last.kind, @campaign.messages.last.character ], "their own character speaks"
  end

  test "there's no speak-as picker: a player with two characters here picks which speaks" do
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".composer select", 0
    assert_select ".composer input[type=hidden][name=character_id][value=?]", characters(:tibbs).id.to_s
    assert_select ".composer__to", "To the table, in character"
    assert_select ".composer textarea[placeholder=?]", "What does Tibbs say?"

    moss = identities(:pip).characters.create!(name: "Moss", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign)
    get campaign_path(@campaign)
    assert_select ".composer input[type=radio][name=character_id]", 2
    post campaign_messages_path(@campaign), params: { context: "story", character_id: moss.id, body: "Hm." }, as: :turbo_stream
    assert_equal moss, @campaign.messages.last.character
  end

    test "a blank message isn't sent, and outsiders can't post" do
    sign_in_as identities(:pip)
    assert_no_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { context: "talk", body: "   " }
    end

    sign_out
    sign_in_as identities(:stranger)
    post campaign_messages_path(@campaign), params: { context: "talk", body: "Hello?" }
    assert_response :not_found
  end

  test "the rail merges chat and log in time order, with Show's choices for each role" do
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
    assert_equal [ "Everything", "Story", "Table talk", "Dice", "Private with the GM" ], css_select(".feed__filter option").map(&:text)
    assert_select ".feed__filter select[name=context][form=?]", "rail_#{@campaign.id}_composer"
    assert_select ".feed__filter option[value=private-gm][data-to=?][data-placeholder=?]", "Privately to the GM", "Only the GM and you see this…"
    assert_select ".table-rail__head .suspense-meter"

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".table-rail .feed__filter option[value=?]", "private-#{identities(:pip).id}", "Private: Tibbs"
    assert_select ".feed__filter option[value=private]", 0, "no one place shows everyone's whispers"
    assert_select ".composer input[type=radio][name=voice][value=narration][checked]"
    assert_select ".composer input[type=radio][name=voice][value=npc]"
    assert_select ".composer input[name=speaker_name]"
    assert_select ".composer textarea[placeholder=?]", "Narrate the scene, or voice an NPC…"
  end

  test "the GM whispers to one player, picked by their character" do
    @campaign.memberships.create!(identity: identities(:stranger), role: :player)
    sign_in_as identities(:gwen)
    post campaign_messages_path(@campaign), params: { context: "private-#{identities(:pip).id}", body: "The miller lies." }, as: :turbo_stream
    assert_response :no_content
    whisper = @campaign.messages.last
    assert_equal [ "whisper", identities(:pip), "Tibbs" ], [ whisper.kind, whisper.recipient, whisper.recipient_name ]

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".chat-line--whisper[data-from=gm][data-to=?] .visually-hidden", identities(:pip).id.to_s, /Gwen to Tibbs, privately/

    sign_out
    sign_in_as identities(:stranger)
    get campaign_path(@campaign)
    assert_no_match "The miller lies.", response.body
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
    assert_select ".chat-line--whisper .visually-hidden", /to the GM, privately/
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

  test "a player deletes their own line, but not someone else's" do
    line = @campaign.messages.create!(identity: identities(:pip), name: "Pip", kind: "table_talk", body: "oops, wrong window")
    gms = @campaign.messages.create!(identity: identities(:gwen), kind: "table_talk", body: "Welcome")

    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".table-rail.table-rail--open", 1
    assert_select ".table-rail--gm", 0, "only their own lines show the button"

    assert_no_difference -> { Message.count } do
      delete campaign_message_path(@campaign, gms), as: :turbo_stream
    end
    assert_response :forbidden

    assert_difference -> { Message.count }, -1 do
      delete campaign_message_path(@campaign, line), as: :turbo_stream
    end
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
