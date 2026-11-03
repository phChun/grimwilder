require "test_helper"

# Share with the table, from the GM table: a poll each player answers in a
# modal on any campaign page (only the GM sees the answers), or a handout, an
# image posted to the chat that only the table can open.
class TableQuestionsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @pip = memberships(:pip_player)
  end

  test "the GM polls with choices, the player answers in the modal, and only the GM sees it" do
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#share input[type=checkbox][name='members[]'][value=?][checked]", @pip.id.to_s

    post campaign_questions_path(@campaign), params: { body: "The door creaks. What do you do?", choices: "Hide\nRun", members: [ @pip.id ] }
    assert_redirected_to campaign_table_path(@campaign, anchor: "share")
    question = @campaign.table_questions.sole

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    frame = "##{@campaign.question_frame_id}"
    assert_select "#{frame} .roll-call__title", "Gwen asks"
    assert_select "#{frame} .table-question__body", "The door creaks. What do you do?"
    assert_select "#{frame} input[type=radio][name=choice]", 2

    patch campaign_question_answer_path(@campaign, question), params: { choice: "Hide", body: "Behind the barrels" }
    assert_redirected_to campaign_asked_question_path(@campaign)
    follow_redirect!
    assert_select ".table-question__sent"
    assert_select "button[type=submit]", "Change my answer"

    get campaign_path(@campaign)
    assert_select ".table-answer", 0, "players never see the answers list"

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#share .table-answer__choice", "Hide"
    assert_select "#share .table-answer__body", "Behind the barrels"

    post campaign_question_closing_path(@campaign, question)
    assert_not question.reload.open?
  end

  test "a blank answer re-renders the modal with the error; a player can't poll or close one" do
    question = TableQuestion.ask!(campaign: @campaign, by: identities(:gwen), members: [ @pip.id ], body: "Who leads?")
    sign_in_as identities(:pip)

    patch campaign_question_answer_path(@campaign, question), params: { body: " " }
    assert_response :unprocessable_entity
    assert_select ".roll-call__error", "Write an answer"

    post campaign_questions_path(@campaign), params: { body: "Me?", members: [ @pip.id ] }
    assert_response :forbidden
    post campaign_question_closing_path(@campaign, question)
    assert_response :forbidden
  end

  test "the GM shares a handout in the chat; the table opens it, no one else can" do
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "form[action=?][enctype='multipart/form-data'] input[type=file][name=image]", campaign_handouts_path(@campaign)
    assert_turbo_stream_broadcasts [ @campaign, :chat ], count: 1 do
      post campaign_handouts_path(@campaign), params: { image: fixture_file_upload("door.png", "image/png"), caption: "Hode's map" }
    end
    handout = @campaign.messages.handout.sole
    assert_equal "Hode's map", handout.body

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "##{dom_id(handout)}.feed-item--talk.feed-item--story img[src=?]", campaign_message_image_path(@campaign, handout)
    get campaign_message_image_path(@campaign, handout)
    assert_equal "image/png", response.media_type
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]

    post campaign_handouts_path(@campaign), params: { image: fixture_file_upload("door.png", "image/png") }
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    get campaign_message_image_path(@campaign, handout)
    assert_response :not_found
  end

  test "a handout needs a raster image, judged by the file itself" do
    sign_in_as identities(:gwen)
    assert_no_difference -> { @campaign.messages.count } do
      post campaign_handouts_path(@campaign), params: { image: fixture_file_upload("sneaky.svg", "image/png") }
      post campaign_handouts_path(@campaign), params: { caption: "No image" }
    end
    follow_redirect!
    assert_select ".toast", /Image is needed for a handout/
  end
end
