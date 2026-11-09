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

  test "the journal card: the player's latest page, and a GM's while it's shared" do
    PlaySession.start!(@campaign, characters: [], by: identities(:gwen))
    memberships(:pip_player).journal.write!(memberships(:pip_player).journal.page("session-1"), "We crossed the bridge.")

    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "details#journal" do
      assert_select "form[action=?] textarea", campaign_journal_page_path(@campaign, memberships(:pip_player), "session-1"), "We crossed the bridge."
      assert_select "input[type=hidden][name=character_id][value=?]", @tibbs.id.to_s
      assert_select "a[href=?]", campaign_journal_path(@campaign, memberships(:pip_player)), "See all journals"
    end

    patch campaign_journal_page_path(@campaign, memberships(:pip_player), "session-1"), params: { character_id: @tibbs.id, journal_entry: { body: "We crossed the bridge, then the river." } }
    assert_redirected_to character_path(@tibbs, anchor: "journal")
    assert_equal "We crossed the bridge, then the river.", memberships(:pip_player).journal.page("session-1").body

    sign_out
    sign_in_as identities(:gwen)
    get character_path(@tibbs)
    assert_select "details#journal" do
      assert_select ".journal-glance__text", "We crossed the bridge, then the river."
      assert_select "textarea", 0
      assert_select "a[href=?]", campaign_journals_path(@campaign), "See all journals"
    end

    memberships(:pip_player).update!(journal_shared: false)
    get character_path(@tibbs)
    assert_select "details#journal .journal-glance", 0
    assert_select "details#journal", /keeps their journal private/
  end
end
