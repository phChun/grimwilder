require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  teardown { Rails.configuration.x.signups_open = true }

  test "home renders the toolkit" do
    get root_path
    assert_response :success
    assert_select "h1", /Grimwilder/
    assert_select "a[href=?]", roll_path
  end

  test "home says what playing at a table and the sheets do" do
    get root_path
    assert_select "h2", "Play at the table"
    assert_select "h2", "Character sheets that roll"
    assert_select ".feature__name", "Roll calls"
    assert_select ".step__desc", /any of the 18 paths/
  end

  test "signed out with sign-ups closed, it offers I'm interested and sign-in, never Start a campaign" do
    Rails.configuration.x.signups_open = false
    get root_path
    assert_select ".home-cta__actions a.button--primary[href=?]", new_interest_path, text: "I'm interested", count: 2
    assert_select ".home-cta__actions a[href=?]", new_session_path
    assert_select "a", text: "Start a campaign", count: 0
    assert_select ".home-close__lede", /closed beta/
  end

  test "signed out with sign-ups open, it offers to start a campaign" do
    get root_path
    assert_select "a[href=?]", new_interest_path, 0
    assert_select ".home-cta__actions a", "Start a campaign"
  end

  test "signed in, the hero leads back to your campaigns and characters" do
    sign_in_as identities(:gwen)
    get root_path
    assert_select "a[href=?]", new_interest_path, 0
    assert_select ".home-cta__actions a[href=?]", campaigns_path, text: "Your campaigns"
    assert_select ".home-cta__actions a[href=?]", characters_path, text: "Your characters"
  end

  test "the footer names the edition the rules follow" do
    get root_path
    assert_select ".site-footer cite", "Grimwild: Community Edition"
  end
end
