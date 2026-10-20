require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  test "asterisks make italics and bold" do
    assert_equal "<em>draws her blade</em> Stand down.", chat_format("*draws her blade* Stand down.")
    assert_equal "That is <strong>not</strong> a goat.", chat_format("That is **not** a goat.")
    assert_equal "<strong>Run</strong>, <em>now</em>!", chat_format("**Run**, *now*!")
  end

  test "stray asterisks stay as typed" do
    assert_equal "2 * 3 * 4", chat_format("2 * 3 * 4")
    assert_equal "a*b*c", chat_format("a*b*c")
    assert_equal "* not this *", chat_format("* not this *")
    assert_equal "**", chat_format("**")
  end

  test "everything else is escaped" do
    assert_equal "&lt;b&gt;hi&lt;/b&gt; <em>&lt;i&gt;</em>", chat_format("<b>hi</b> *<i>*")
    assert_predicate chat_format("x"), :html_safe?
  end

  test "the chat line renders it" do
    message = Message.new(kind: "table_talk", name: "Pip", body: "*shrugs*", identity_id: 1, campaign: campaigns(:bramblewood), created_at: Time.current)
    render "messages/message", message: message
    assert_select ".chat-line__body em", "shrugs"
  end
end
