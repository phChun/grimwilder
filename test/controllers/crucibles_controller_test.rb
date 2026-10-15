require "test_helper"

class CruciblesControllerTest < ActionDispatch::IntegrationTest
  test "index lists crucibles by group, no account needed" do
    get crucibles_path
    assert_response :success
    assert_select "h2", text: "For the GM"
    assert_select "a[href=?]", crucible_path("gm")
  end

  test "show renders each table as a 6x6 grid" do
    get crucible_path("buildings")
    assert_response :success
    assert_select "[data-controller=crucible] [data-crucible-target=table]", 2
    assert_select "td[data-row='6'][data-col='2']", text: "fortune teller"
  end

  test "unknown crucibles are a 404" do
    get crucible_path("nope")
    assert_response :not_found
  end
end
