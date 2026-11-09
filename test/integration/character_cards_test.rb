require "test_helper"

class CharacterCardsTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs)
    @campaign = campaigns(:bramblewood)
  end

  test "the sheet's cards fold, all but the stats and harm" do
    sign_in_as identities(:pip)
    get character_path(@tibbs)

    %w[ talents who story journal ].each do |id|
      assert_select "details##{id}.sheet-fold[data-details-memory-target=section] > summary.gm-fold__summary"
    end
    assert_select "details#talents[data-section=?]", "character-#{@tibbs.id}-talents"
    assert_equal %w[ talents table-rolls journal arcana story who ], css_select("details.sheet-fold").map { _1["id"] }
    assert_equal %w[ talents who ], css_select("details.sheet-fold[open]").map { _1["id"] }
    assert_select "#table-rolls .sheet-fold__count[aria-label*=?]", "pool", /\A\d+\z/
    assert_select "#stats", 1
    assert_select "details#stats, details#damage", 0
  end

  test "who they are edits in its card, and only those fields save there" do
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "turbo-frame#character_profile a[href=?]", edit_character_profile_path(@tibbs), "Edit"

    get edit_character_profile_path(@tibbs)
    assert_select "turbo-frame#character_profile form[action=?]", character_profile_path(@tibbs) do
      assert_select "input[name='character[traits][]']", 2
      assert_select "input[name='character[backgrounds][0][name]']"
      assert_select "input[name='character[arcs][]']", 0
    end

    patch character_profile_path(@tibbs), params: { character: { traits: %w[ brave curious ], weapons: "a cane", arcs: [ "sneaked in" ], brawn: 3, notes: "sneaked in" } }
    assert_redirected_to character_profile_path(@tibbs)
    @tibbs.reload
    assert_equal %w[ brave curious ], @tibbs.traits
    assert_equal "a cane", @tibbs.weapons
    assert_equal 1, @tibbs.brawn
    assert_not_equal [ "sneaked in" ], @tibbs.arcs
    assert_not_equal "sneaked in", @tibbs.notes
  end

  test "the story edits in its card, and only bonds, arcs and notes save there" do
    sign_in_as identities(:pip)
    get edit_character_story_path(@tibbs)
    assert_select "turbo-frame#character_story form[action=?]", character_story_path(@tibbs) do
      assert_select "input[name='character[arcs][]']", 2
      assert_select "textarea[name='character[notes]']"
      assert_select "input[name='character[traits][]']", 0
    end

    patch character_story_path(@tibbs), params: { character: { arcs: [ "find the heir" ], notes: "Owes the miller.", traits: [ "sneaky" ] } }
    assert_redirected_to character_story_path(@tibbs)
    @tibbs.reload
    assert_equal [ "find the heir" ], @tibbs.arcs
    assert_equal "Owes the miller.", @tibbs.notes
    assert_not_includes @tibbs.traits, "sneaky"
  end

  test "the card's page on its own goes back to the sheet" do
    sign_in_as identities(:pip)
    get character_story_path(@tibbs)
    assert_redirected_to character_path(@tibbs, anchor: "story")

    get character_profile_path(@tibbs), headers: { "Turbo-Frame" => "character_profile" }
    assert_response :success
    assert_select "turbo-frame#character_profile .facts"
  end

  test "the edit sheet no longer changes who they are or their story" do
    sign_in_as identities(:pip)
    get edit_character_path(@tibbs)
    assert_select "input[name='character[traits][]']", 0
    assert_select "textarea[name='character[notes]']", 0

    patch character_path(@tibbs), params: { character: { name: "Tibbs", traits: [ "sneaky" ], notes: "Nope" } }
    @tibbs.reload
    assert_equal "Tibbs", @tibbs.name
    assert_not_includes @tibbs.traits, "sneaky"
    assert_not_equal "Nope", @tibbs.notes
  end

  test "only the owner edits the cards" do
    sign_in_as identities(:gwen)
    get character_path(@tibbs)
    assert_select "a[href=?]", edit_character_profile_path(@tibbs), 0
    assert_select "a[href=?]", edit_character_story_path(@tibbs), 0

    get edit_character_profile_path(@tibbs)
    assert_response :not_found
    patch character_story_path(@tibbs), params: { character: { notes: "GM was here" } }
    assert_response :not_found
  end

  test "the journal card: a New page button that opens its form, then the latest pages, each opened from its title" do
    pip = memberships(:pip_player)
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "details#journal" do
      assert_select "turbo-frame#journal_new a[href=?]", new_campaign_journal_page_path(@campaign, pip, character_id: @tibbs.id), "New page"
      assert_select "hr.journal__rule + .empty", "No pages yet."
      assert_select "a[href=?]", campaign_journal_path(@campaign, pip), "Open the journal"
    end

    get new_campaign_journal_page_path(@campaign, pip, character_id: @tibbs.id)
    assert_select "turbo-frame#journal_new" do
      assert_select "form[action=?][method=post] textarea", campaign_journal_pages_path(@campaign, pip)
      assert_select "input[type=hidden][name=character_id][value=?]", @tibbs.id.to_s
      assert_select "input[name='journal_page[locked]']", 0
      assert_select "a.button--danger[href=?]", character_path(@tibbs), "Cancel"
    end

    post campaign_journal_pages_path(@campaign, pip), params: { character_id: @tibbs.id, journal_page: { title: "", body: "We crossed the bridge." } }
    assert_redirected_to character_path(@tibbs, anchor: "journal")
    page = pip.journal_pages.sole
    get character_path(@tibbs)
    assert_select "details#journal .journal-page--compact details.journal-page__fold:not([open])" do
      assert_select "summary .journal-page__title", page.heading
      assert_select "summary a", 0, "the title folds the page open, it doesn't link"
      assert_select ".journal-page__text", "We crossed the bridge."
      assert_select ".journal-page__actions a[href=?][data-turbo-frame=modal]", campaign_journal_page_path(@campaign, pip, page, character_id: @tibbs.id), "Edit"
    end
    post campaign_journal_page_favorite_path(@campaign, pip, page), params: { character_id: @tibbs.id }
    assert_redirected_to character_path(@tibbs, anchor: "journal")

    sign_out
    sign_in_as identities(:gwen)
    get character_path(@tibbs)
    assert_select "details#journal" do
      assert_select ".journal-page__text", "We crossed the bridge."
      assert_select ".journal-page__star--on[title=Starred]"
      assert_select ".journal-page__actions", 0, "the GM reads the player's page, no Edit"
    end
    get new_campaign_journal_page_path(@campaign, pip, character_id: @tibbs.id)
    assert_select "input[type=checkbox][name='journal_page[locked]'][checked]"

    pip.update!(journal_shared: false)
    get character_path(@tibbs)
    assert_select "details#journal .journal-page", 0
    assert_select "details#journal", /keeps their journal private/

    post campaign_journal_pages_path(@campaign, pip), params: { character_id: @tibbs.id, journal_page: { title: "Who you were", body: "A thief, once.", locked: "1" } }
    get character_path(@tibbs)
    assert_select "details#journal .journal-page__text", "A thief, once.", "the GM always sees the GM's pages"
  end

  test "the journal card shows the starred pages and the latest, then See all" do
    pip = memberships(:pip_player)
    starred = pip.journal.write!(pip, title: "Oaths", body: "Kept.", favorite: true)
    travel 1.minute
    middle = pip.journal.write!(pip, title: "The bridge", body: "Crossed.")
    travel 1.minute
    latest = pip.journal.write!(pip, title: "The river", body: "Swum.")

    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_equal [ "page-#{starred.id}", "page-#{latest.id}" ], css_select("details#journal .journal-page").map { _1["id"] }
    assert_equal %w[ Favorites Latest ], css_select("details#journal .journal-glance__heading").map(&:text)
    assert_select "#sheet_journal_favorites + #page-#{starred.id}"
    assert_select "#sheet_journal_latest + #page-#{latest.id}"
    assert_select "details#journal a[href=?]", campaign_journal_path(@campaign, pip), "See all 3 pages"

    travel 1.minute
    middle.update!(body: "Crossed, twice.")
    get character_path(@tibbs)
    assert_equal [ "page-#{starred.id}", "page-#{middle.id}" ], css_select("details#journal .journal-page").map { _1["id"] }, "the latest is the last one written in"

    starred.update!(favorite: false)
    middle.update!(favorite: true)
    get character_path(@tibbs)
    assert_equal [ "page-#{middle.id}" ], css_select("details#journal .journal-page").map { _1["id"] }, "a starred latest shows once"
    assert_equal %w[ Favorites ], css_select("details#journal .journal-glance__heading").map(&:text), "no Latest heading for nothing"
  end
end
