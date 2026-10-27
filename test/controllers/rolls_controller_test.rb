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

  test "the talent dice rules fold under the setup" do
    get roll_path
    assert_select ".roller__talents" do
      assert_select "button[data-herb-increment=assists]"
      assert_select "button[data-herb-increment=panache]"
      %w[ teamwork reckless spell ].each { assert_select "input[type=checkbox][data-herb-toggle=?]", _1 }
    end
  end
end
