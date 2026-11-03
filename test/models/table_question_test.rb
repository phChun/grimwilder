require "test_helper"

class TableQuestionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @campaign = campaigns(:bramblewood)
    @gm, @pip = memberships(:gwen_gm), memberships(:pip_player)
  end

  def ask(**options)
    TableQuestion.ask!(campaign: @campaign, by: identities(:gwen), members: [ @pip.id ], body: "Left or right?", **options)
  end

  test "the GM asks the players they pick, each getting an empty answer; only players count" do
    question = ask(members: [ @pip.id, @gm.id ], choices: "Left\n\n Right \nLeft")

    assert_equal %w[ Left Right ], question.choices
    assert_equal [ @pip ], question.answers.map(&:membership)
    assert_equal "Pip", question.answers.sole.name
    assert_not question.answers.sole.answered?
  end

  test "it needs a GM, a player and a question" do
    assert_raises(ActiveRecord::RecordInvalid) { TableQuestion.ask!(campaign: @campaign, by: identities(:pip), members: [ @pip.id ], body: "Hi") }
    assert_raises(ActiveRecord::RecordInvalid) { ask(members: []) }
    assert_raises(ActiveRecord::RecordInvalid) { ask(body: " ") }
    assert_raises(ActiveRecord::RecordInvalid) { ask(choices: (1..7).map(&:to_s)) }
  end

  test "a player answers with a choice or words, until it closes; the oldest unanswered shows first" do
    first, second = ask(choices: %w[ Left Right ]), ask(body: "Who leads?")
    assert_equal first, TableQuestion.showing_for(@campaign, @pip).table_question
    assert_nil TableQuestion.showing_for(@campaign, @gm)

    answer = first.answers.sole
    assert_raises(ActiveRecord::RecordInvalid) { answer.answer!(choice: "Up") }
    assert_raises(ActiveRecord::RecordInvalid) { answer.answer! }
    answer.answer!(choice: "Left", body: "Quietly")
    assert_equal [ "Left", "Quietly" ], [ answer.reload.choice, answer.body ]
    assert_equal second, TableQuestion.showing_for(@campaign, @pip).table_question

    second.answers.sole.answer!(body: "Tibbs")
    assert_equal second, TableQuestion.showing_for(@campaign, @pip).table_question, "the newest answered, to change it"

    first.close!
    second.close!
    assert_nil TableQuestion.showing_for(@campaign, @pip)
    assert_raises(ActiveRecord::RecordInvalid) { answer.answer!(choice: "Right") }
  end

  test "the GM's list updates live as answers come in and change" do
    question = perform_enqueued_jobs { ask }
    answer = question.answers.sole

    perform_enqueued_jobs { answer.answer!(body: "Left, quietly") }
    perform_enqueued_jobs { answer.answer!(body: "Right, loudly") }
    replaced = capture_turbo_stream_broadcasts([ @campaign, :questions ]).select { _1["action"] == "replace" }

    assert_equal 2, replaced.size
    assert_includes replaced.last.to_html, "Right, loudly"
  end

  test "not once the campaign is archived" do
    @campaign.update_columns(archived_at: Time.current)
    assert_raises(ActiveRecord::RecordInvalid) { ask }
  end
end
