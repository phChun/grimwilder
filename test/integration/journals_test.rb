require "test_helper"

class JournalsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @pip = memberships(:pip_player)
    PlaySession.start!(@campaign, characters: [], by: identities(:gwen))
  end

  test "a player writes this session's page, then another, and can keep it from the GM" do
    sign_in_as identities(:pip)
    get campaign_journal_path(@campaign, @pip)
    assert_select ".tabs__link[aria-current]", "Journal"
    assert_select "#page-session-1.journal-page--current textarea"

    patch campaign_journal_page_path(@campaign, @pip, "session-1"), params: { journal_entry: { body: "We crossed the bridge." } }
    assert_redirected_to campaign_journal_path(@campaign, @pip, anchor: "page-session-1")
    assert_equal "We crossed the bridge.", @pip.journal_entries.sole.body

    get edit_campaign_journal_page_path(@campaign, @pip, "before")
    assert_response :success
    get edit_campaign_journal_page_path(@campaign, @pip, "after-7")
    assert_response :not_found

    patch campaign_journal_path(@campaign, @pip), params: { membership: { journal_shared: "0" } }
    assert_not @pip.reload.journal_shared?
  end

  test "the GM reads shared journals, and not private ones; other players never do" do
    @pip.journal.write!(@pip.journal.page("session-1"), "We crossed *the bridge*. **Never again.** <b>no</b>")
    sign_in_as identities(:gwen)
    get campaign_journals_path(@campaign)
    assert_select ".journal-list__item", /Pip.*1 page/m
    get campaign_journal_path(@campaign, @pip)
    assert_select ".journal-page__text em", "the bridge"
    assert_select ".journal-page__text strong", "Never again."
    assert_select ".journal-page__text b", 0, "anything else typed stays text"
    assert_select ".journal-page__text", /<b>no<\/b>/
    assert_select "textarea", 0
    patch campaign_journal_page_path(@campaign, @pip, "session-1"), params: { journal_entry: { body: "Edited." } }
    assert_response :not_found

    @pip.update!(journal_shared: false)
    get campaign_journal_path(@campaign, @pip)
    assert_response :not_found
    get campaign_journals_path(@campaign)
    assert_select ".journal-list__item", /Kept private/
  end
end
