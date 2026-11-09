require "test_helper"

class JournalsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @pip = memberships(:pip_player)
  end

  test "a player adds pages, changes and tears them out, and can keep the journal from the GM" do
    sign_in_as identities(:pip)
    get campaign_journal_path(@campaign, @pip)
    assert_select ".tabs__link[aria-current]", "Journal"
    assert_select ".journal-new form[action=?] textarea", campaign_journal_pages_path(@campaign, @pip)

    post campaign_journal_pages_path(@campaign, @pip), params: { journal_page: { title: "The bridge", body: "We crossed it." } }
    page = @pip.journal_pages.sole
    assert_redirected_to campaign_journal_path(@campaign, @pip, anchor: "page-#{page.id}")
    follow_redirect!
    assert_select "#page-#{page.id} .journal-page__title", "The bridge"

    get edit_campaign_journal_page_path(@campaign, @pip, page)
    assert_select "input[name='journal_page[locked]']", 0
    patch campaign_journal_page_path(@campaign, @pip, page), params: { journal_page: { title: "", body: "We crossed the river." } }
    assert_equal [ nil, "We crossed the river." ], page.reload.then { [ _1.title, _1.body ] }

    delete campaign_journal_page_path(@campaign, @pip, page)
    assert_redirected_to campaign_journal_path(@campaign, @pip)
    assert_empty @pip.journal_pages

    patch campaign_journal_path(@campaign, @pip), params: { membership: { journal_shared: "0" } }
    assert_not @pip.reload.journal_shared?
  end

  test "the GM reads shared journals and adds locked pages; the player reads those but can't change them" do
    mine = @pip.journal.write!(@pip, title: nil, body: "We crossed *the bridge*. **Never again.** <b>no</b>")
    sign_in_as identities(:gwen)
    get campaign_journals_path(@campaign)
    assert_select ".journal-list__item", /Pip.*1 page/m
    get campaign_journal_path(@campaign, @pip)
    assert_select ".journal-page__text em", "the bridge"
    assert_select ".journal-page__text strong", "Never again."
    assert_select ".journal-page__text b", 0, "anything else typed stays text"
    assert_select ".journal-page__text", /<b>no<\/b>/
    assert_select "#page-#{mine.id} a", text: "Edit", count: 0
    patch campaign_journal_page_path(@campaign, @pip, mine), params: { journal_page: { body: "Edited." } }
    assert_response :not_found

    post campaign_journal_pages_path(@campaign, @pip), params: { journal_page: { title: "Who you were", body: "A thief, once.", locked: "1" } }
    secret = @pip.journal_pages.by_gm.sole
    assert secret.locked?

    @pip.update!(journal_shared: false)
    get campaign_journal_path(@campaign, @pip)
    assert_select ".journal-page", 1
    assert_select "#page-#{secret.id}", /A thief, once/
    get campaign_journals_path(@campaign)
    assert_select ".journal-list__item", /Kept private/

    sign_out
    sign_in_as identities(:pip)
    get campaign_journal_path(@campaign, @pip)
    assert_select "#page-#{secret.id} .journal-page__tag", "From the GM"
    assert_select "#page-#{secret.id} .journal-page__tag", "Read only"
    assert_select "#page-#{secret.id} a", text: "Edit", count: 0
    patch campaign_journal_page_path(@campaign, @pip, secret), params: { journal_page: { body: "Not a thief." } }
    assert_response :not_found
    delete campaign_journal_page_path(@campaign, @pip, secret)
    assert_response :not_found
  end
end
