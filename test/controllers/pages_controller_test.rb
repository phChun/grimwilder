require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders the toolkit" do
    get root_path
    assert_response :success
    assert_select "h1", /Grimwilder/
    assert_select "a[href=?]", roll_path
  end

  test "the footer names the edition the rules follow" do
    get root_path
    assert_select ".site-footer cite", "Grimwild: Community Edition Preview 6"
  end
end
