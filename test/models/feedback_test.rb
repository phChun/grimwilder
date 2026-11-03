require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "it keeps the page and the route behind it, and only takes this site's pages" do
    feedback = identities(:gwen).feedbacks.create!(path: "/campaigns/#{campaigns(:bramblewood).id}/table?x=1", body: "  The clock is great.  ", user_agent: "Safari")
    assert_equal [ "campaigns/tables#show", "The clock is great." ], [ feedback.route, feedback.body ]

    assert_nil identities(:gwen).feedbacks.create!(path: "/nowhere/at/all", body: "Hm").route
    assert_not identities(:gwen).feedbacks.new(path: "//evil.example/x", body: "Hi").valid?
    assert_not identities(:gwen).feedbacks.new(path: "https://evil.example", body: "Hi").valid?
    assert_not identities(:gwen).feedbacks.new(path: "/", body: " ").valid?
  end

  test "as Markdown: each item's page, route, sender by name only, browser and words" do
    identities(:gwen).feedbacks.create!(path: "/roll", body: "Dice are slow.\nOn my phone.", user_agent: "Firefox", created_at: Time.utc(2026, 11, 3, 12))
    identities(:pip).feedbacks.create!(path: "/talents", body: "Love it.", created_at: Time.utc(2026, 11, 3, 13))

    markdown = Feedback.to_markdown(Feedback.newest_first, exported_at: Time.utc(2026, 11, 3, 14))
    assert_match "2 items, newest first, exported 2026-11-03 14:00 UTC", markdown
    assert_match "## 1. /talents\n\n- From: Pip\n- When: 2026-11-03 13:00 UTC\n- Route: `talents#index`\n\n> Love it.", markdown
    assert_match "## 2. /roll", markdown
    assert_match "- Browser: Firefox\n\n> Dice are slow.\n> On my phone.", markdown
    assert_no_match "@example.com", markdown, "no email addresses go to the AI"
  end
end
