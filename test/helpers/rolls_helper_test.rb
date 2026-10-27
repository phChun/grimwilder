require "test_helper"

class RollsHelperTest < ActionView::TestCase
  test "a level-up asks for a talent, or at level 1 (from level 0) the last stat point" do
    tibbs = characters(:tibbs)
    assert_dom_equal link_to("choose a talent", new_character_talent_path(tibbs)), level_up_link("character_id" => tibbs.id, "level" => 2)
    assert_dom_equal link_to("add the last stat point", character_path(tibbs, anchor: "stats")), level_up_link("character_id" => tibbs.id, "level" => 1)
  end
end
