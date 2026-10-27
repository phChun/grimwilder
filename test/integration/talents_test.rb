require "test_helper"

class TalentsTest < ActionDispatch::IntegrationTest
  test "the catalog is public" do
    get talents_path
    assert_response :success
    assert_select "#group-rogue h2", text: "The Rogue"
    assert_select "#talent-expertise .tag", text: "Core"
    assert_select "#talent-eldritch-affinity .tag", text: "Not for Sorcerer"

    assert_select "#talent-lucky > .talent__summary", Talent.find("lucky").summary
    assert_select "#talent-lucky > details.talent__more:not([open])" do
      assert_select "summary", "From the book"
      assert_select ".talent__text p", /1d Luck pool/
    end
    assert_select "#talent-lucky > .talent__text", 0, "the book text is folded away"
  end

  test "a dropdown shows one path's talents, or all of them" do
    get talents_path
    assert_select "select#talent-path[data-talent-filter-target=path]" do
      assert_select "option", Talent.groups.size + 1
      assert_select "option[selected]", "All talents"
      assert_select "option[value=warlock]", "Warlock"
      assert_select "option[value=backgrounds]", "Background and heritage"
    end
    assert_select "section.talent-group[hidden]", 0, "all of them to start"

    get talents_path(path: "warlock")
    assert_select "select#talent-path option[selected][value=warlock]"
    assert_select "section.talent-group:not([hidden])", 1
    assert_select "section#group-warlock:not([hidden])"

    get talents_path(path: "nonsense")
    assert_select "section.talent-group[hidden]", 0
  end

  test "choose a talent for your character" do
    tibbs = characters(:tibbs)
    sign_in_as identities(:pip)

    get new_character_talent_path(tibbs)
    assert_response :success
    assert_select "section.talent-group:first-of-type h2", text: "The Rogue"
    assert_select "select#talent-path option[selected][value=rogue]", 1, "opens on the character's own path"
    assert_select "section.talent-group:not([hidden])", 1
    assert_select "#talent-mastermind input[type=checkbox][name='talents[]'][form=talent-list][checked]"
    assert_select "#talent-lucky input[type=checkbox][name='talents[]']:not([checked])"
    assert_select "#talent-picker-panel .talent-picker__count", "1 of 1"
    assert_select "#talent-picker-panel .talent-picker__item", "Mastermind"

    patch character_talent_list_path(tibbs), params: { talents: [ "", "mastermind", "lucky" ] }
    assert_redirected_to new_character_talent_path(tibbs)
    assert_not_includes tibbs.reload.talent_keys, "lucky", "level 1 has room for one"

    tibbs.update!(level: 3)
    patch character_talent_list_path(tibbs), params: { talents: [ "", "mastermind", "lucky", "weasel" ] }
    assert_redirected_to character_path(tibbs, anchor: "talents")
    assert_equal "Gibbletibble \"Tibbs\" took Lucky and Weasel.", flash[:notice]
    assert_equal %w[ mastermind lucky weasel ], tibbs.reload.talent_keys

    patch character_talent_list_path(tibbs), params: { talents: [ "", "lucky", "weasel", "lurker" ] }
    assert_equal %w[ lucky weasel lurker ], tibbs.reload.talent_keys, "a swap in one save"
    assert_match "took Lurker and dropped Mastermind", flash[:notice]

    post character_talents_path(tibbs), params: { talent: "poisoner" }
    assert_not_includes tibbs.reload.talent_keys, "poisoner", "taking one alone still checks the room"

    delete character_talent_path(tibbs, "lucky")
    assert_not_includes tibbs.reload.talent_keys, "lucky"
  end

  test "a sheet with more talents than its level asks for one to go" do
    tibbs = characters(:tibbs)
    tibbs.update_columns(talent_keys: %w[mastermind lucky])
    sign_in_as identities(:pip)

    get character_path(tibbs)
    assert_select ".talent-over", /Level 1 has room for 1 talent besides Expertise/
    get new_character_talent_path(tibbs)
    assert_select ".page-header__lede", /1 more than level 1 allows/
  end

    test "a warlock picks Eldritch Talents in their own slots" do
    vex = identities(:pip).characters.create!(name: "Vex", path: "Warlock", brawn: 1, agility: 2, wits: 2, presence: 3, talent_keys: [ "affliction" ])
    sign_in_as identities(:pip)

    get character_path(vex)
    assert_select ".eldritch__count", "0 of 1"
    assert_select ".eldritch a.talent-slot[href=?]", new_character_talent_path(vex, eldritch: 1), "Pick an Eldritch Talent"

    get new_character_talent_path(vex, eldritch: 1)
    assert_select "h1", "Choose an Eldritch Talent"
    assert_select "#talent-lucky input[type=checkbox][name='talents[]']"
    assert_select "#talent-affliction .tag", "Taken"
    assert_select "section.talent-group h2", text: "Background and heritage", count: 0

    assert_select "#talent-list input[type=hidden][name=eldritch][value='1']"
    patch character_talent_list_path(vex), params: { talents: [ "", "lucky" ], eldritch: 1 }
    assert_redirected_to character_path(vex, anchor: "talents")
    assert_equal [ "lucky" ], vex.reload.eldritch_talent_keys
    assert_equal [ "affliction" ], vex.talent_keys

    get character_path(vex)
    assert_select ".eldritch #talent-lucky .talent-card__source", /Eldritch/
    assert_select ".eldritch .talent-slot", 0
    get new_character_talent_path(vex, eldritch: 1)
    assert_select "#talent-picker-panel .talent-picker__count", "1 of 1"
    patch character_talent_list_path(vex), params: { talents: [ "", "lucky", "bulwark" ], eldritch: 1 }
    assert_equal [ "lucky" ], vex.reload.eldritch_talent_keys, "no second slot at level 1"

    delete character_talent_path(vex, "lucky", eldritch: 1)
    assert_empty vex.reload.eldritch_talent_keys
  end

  test "other paths have no Eldritch Talents" do
    sign_in_as identities(:pip)
    get new_character_talent_path(characters(:tibbs), eldritch: 1)
    assert_response :not_found
    get character_path(characters(:tibbs))
    assert_select ".eldritch", 0
  end

    test "a core or prohibited talent is refused" do
    tibbs = characters(:tibbs)
    sign_in_as identities(:pip)

    post character_talents_path(tibbs), params: { talent: "sorcery" }
    assert_redirected_to new_character_talent_path(tibbs)
    assert_not_includes tibbs.reload.talent_keys, "sorcery"
  end

  test "only the owner chooses talents" do
    sign_in_as identities(:gwen)

    post character_talents_path(characters(:tibbs)), params: { talent: "lucky" }
    assert_response :not_found
  end
end
