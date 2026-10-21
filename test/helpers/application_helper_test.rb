require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "title_case capitalizes each word, keeping short words and existing capitals" do
    assert_equal "Uncover the Truth", title_case("uncover the truth")
    assert_equal "Laws of the Land", title_case("laws of the land")
    assert_equal "The Way Out", title_case("the way out")
    assert_equal "Quick-Witted", title_case("quick-witted")
    assert_equal "Lowkey Affection", title_case("  lowkey   affection ")
    assert_equal "NPC Wrangling", title_case("NPC wrangling")
    assert_equal "", title_case(nil)
  end
end
