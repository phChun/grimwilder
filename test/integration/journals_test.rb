require "test_helper"

class JournalsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @pip = memberships(:pip_player)
  end

  test "a player adds pages, stars, changes and tears them out, and can keep the journal from the GM" do
    sign_in_as identities(:pip)
    get campaign_journal_path(@campaign, @pip)
    assert_select ".tabs__link[aria-current]", "Journal"
    assert_select "turbo-frame#journal_new a[href=?]", new_campaign_journal_page_path(@campaign, @pip), "New page"
    assert_select ".journal__rule + .empty", "No pages yet."

    get new_campaign_journal_page_path(@campaign, @pip)
    assert_select "turbo-frame#journal_new form[action=?] textarea", campaign_journal_pages_path(@campaign, @pip)
    assert_select "turbo-frame#journal_new .journal-form__actions input[type=submit][value=?] + a.button--danger[href=?]", "Add page", campaign_journal_path(@campaign, @pip), text: "Cancel"

    assert_select "turbo-frame#journal_new input[type=checkbox][name='journal_page[favorite]']:not([checked])"
    post campaign_journal_pages_path(@campaign, @pip), params: { journal_page: { title: "The bridge", body: "We crossed it." } }
    page = @pip.journal_pages.sole
    assert_redirected_to campaign_journal_path(@campaign, @pip, anchor: "page-#{page.id}")
    follow_redirect!
    assert_select "#page-#{page.id} .journal-page__title", "The bridge"

    post campaign_journal_page_favorite_path(@campaign, @pip, page)
    assert page.reload.favorite?
    get campaign_journal_path(@campaign, @pip)
    assert_select "#page-#{page.id}.journal-page--favorite form[action=?] button[aria-label=?]", campaign_journal_page_favorite_path(@campaign, @pip, page), "Unstar The bridge"
    delete campaign_journal_page_favorite_path(@campaign, @pip, page)
    assert_not page.reload.favorite?

    get campaign_journal_path(@campaign, @pip)
    assert_select "#page-#{page.id} .journal-page__title a[href=?][data-turbo-frame=modal]", campaign_journal_page_path(@campaign, @pip, page), "The bridge"
    get campaign_journal_page_path(@campaign, @pip, page)
    assert_select "turbo-frame#modal textarea", "We crossed it."
    assert_select "input[name='journal_page[locked]']", 0
    patch campaign_journal_page_path(@campaign, @pip, page), params: { journal_page: { title: "", body: "We crossed the river." } }
    assert_equal [ nil, "We crossed the river." ], page.reload.then { [ _1.title, _1.body ] }

    delete campaign_journal_page_path(@campaign, @pip, page)
    assert_redirected_to campaign_journal_path(@campaign, @pip)
    assert_empty @pip.journal_pages

    post campaign_journal_pages_path(@campaign, @pip), params: { journal_page: { title: "Keep", body: "On top.", favorite: "1" } }
    assert @pip.journal_pages.sole.favorite?, "a new page can start starred"

    get campaign_journal_path(@campaign, @pip, sort: "chronologically")
    assert_select "form.journal__sort[method=get] select[name=sort] option[selected][value=chronologically]", "Chronologically"
    assert_equal [ "Favorites first", "Chronologically", "Last updated" ], css_select("select#journal_sort option").map(&:text)

    patch campaign_journal_path(@campaign, @pip), params: { membership: { journal_shared: "0" } }
    assert_not @pip.reload.journal_shared?
  end

  test "the GM reads shared journals and adds locked pages; the player reads those but can't change them, and only the player stars" do
    mine = @pip.journal.write!(@pip, title: nil, body: "We crossed *the bridge*. **Never again.** <b>no</b>")
    sign_in_as identities(:gwen)
    get campaign_journals_path(@campaign)
    assert_select ".journal-list__item", /Pip.*1 page/m
    get campaign_journal_path(@campaign, @pip)
    assert_select ".journal-page__text em", "the bridge"
    assert_select ".journal-page__text strong", "Never again."
    assert_select ".journal-page__text b", 0, "anything else typed stays text"
    assert_select ".journal-page__text", /<b>no<\/b>/
    get campaign_journal_page_path(@campaign, @pip, mine)
    assert_select "turbo-frame#modal .journal-page__text em", "the bridge"
    assert_select "turbo-frame#modal textarea", 0
    assert_select ".journal-page__star", 0
    post campaign_journal_page_favorite_path(@campaign, @pip, mine)
    assert_response :not_found
    patch campaign_journal_page_path(@campaign, @pip, mine), params: { journal_page: { body: "Edited." } }
    assert_response :not_found

    get new_campaign_journal_page_path(@campaign, @pip)
    assert_select "input[name='journal_page[favorite]']", 0, "only the player stars"
    post campaign_journal_pages_path(@campaign, @pip), params: { journal_page: { title: "Who you were", body: "A thief, once.", locked: "1", favorite: "1" } }
    secret = @pip.journal_pages.by_gm.sole
    assert secret.locked?
    assert_not secret.favorite?

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
    get campaign_journal_page_path(@campaign, @pip, secret)
    assert_select "turbo-frame#modal .journal-page__text", "A thief, once."
    assert_select "turbo-frame#modal textarea", 0
    patch campaign_journal_page_path(@campaign, @pip, secret), params: { journal_page: { body: "Not a thief." } }
    assert_response :not_found
    delete campaign_journal_page_path(@campaign, @pip, secret)
    assert_response :not_found
  end
end
