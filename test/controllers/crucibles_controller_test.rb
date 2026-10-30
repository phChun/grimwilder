require "test_helper"

class CruciblesControllerTest < ActionDispatch::IntegrationTest
  test "index lists crucibles by group, no account needed" do
    get crucibles_path
    assert_response :success
    assert_select "h2", text: "For the GM"
    assert_select "a[href=?]", crucible_path("gm")
  end

  test "index can be searched by name, blurb or any word a crucible rolls" do
    get crucibles_path
    assert_select "[data-controller=crucible-filter] input[type=search][data-crucible-filter-target=query]"
    assert_select "li[data-crucible-filter-target=item]", Crucible.all.size
    assert_select "li[data-search*='lucrative rumor'] a[href=?]", crucible_path("treasure")
  end

  test "show renders each table as a 6x6 grid" do
    get crucible_path("buildings")
    assert_response :success
    assert_select "[data-controller=crucible] [data-crucible-target=table]", 2
    assert_select ".crucible__tables[data-count='2']"
    assert_select "td[data-row='6'][data-col='2']", text: "fortune teller"
  end

  test "one-column lists have no heading row; narrower tables name the die's faces" do
    get crucible_path("eldritch_mutations")
    assert_select ".grid66 thead", 0

    get crucible_path("legend")
    assert_select ".grid66 thead th", text: "Playful 1–2"

    get crucible_path("vassal")
    assert_select ".grid66 thead th", text: "1–3"
  end

  test "a d8 table says so to the roller and has no heading row" do
    get crucible_path("solo_high_stakes")
    assert_select "[data-crucible-target=table][data-rows='8'][data-width='2']"
    assert_select ".grid66 thead", 0
    assert_select ".grid66 tbody tr", 8
  end

  test "unknown crucibles are a 404" do
    get crucible_path("nope")
    assert_response :not_found
  end

  test "the monster tables are listed under Monsters and roll with one die" do
    get crucibles_path
    assert_select "h2", "Monsters"

    get crucible_path("monster_cyclopean_curses")
    assert_response :success
    assert_select "*", text: /It's lonely, the last of its kind\./
    assert_select ".crucible__tables[data-count='1'] .crucible-table[data-width='1']"
  end
end
