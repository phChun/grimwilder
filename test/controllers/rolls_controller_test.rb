require "test_helper"

class RollsControllerTest < ActionDispatch::IntegrationTest
  test "action roller renders with its controls" do
    get roll_path
    assert_response :success
    assert_select "[data-controller=roller]"
    assert_select "button[data-herb-increment=stat]"
    assert_select "button[data-herb-increment=thorns]"
    assert_select "button[data-action~='roller#roll']"
  end
end
