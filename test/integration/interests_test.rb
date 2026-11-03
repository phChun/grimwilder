require "test_helper"

class InterestsTest < ActionDispatch::IntegrationTest
  test "anyone can say they're interested, and asking again updates it" do
    get new_interest_path
    assert_response :success

    assert_difference -> { Interest.count } do
      post interest_path, params: { interest: { email_address: " Ana@Example.com ", role: "gm", note: "A group of four." } }
    end
    assert_redirected_to interest_path
    follow_redirect!
    assert_select "h1", /on the list/

    assert_no_difference -> { Interest.count } do
      post interest_path, params: { interest: { email_address: "ana@example.com", role: "both", note: "" } }
    end
    interest = Interest.sole
    assert_equal [ "ana@example.com", "both", nil ], [ interest.email_address, interest.role, interest.note ]
  end

  test "a bad email shows the form again" do
    post interest_path, params: { interest: { email_address: "nope", role: "" } }
    assert_response :unprocessable_entity
    assert_select ".form-error", /Email address is invalid/
  end

  test "a note past 500 characters shows the form again" do
    post interest_path, params: { interest: { email_address: "long@example.com", note: "x" * 501 } }
    assert_response :unprocessable_entity
    assert_select ".form-error", /Note is too long/
    assert_select "textarea[maxlength='500']"
  end

  test "a filled-in honeypot is thanked and saves nothing" do
    assert_no_difference -> { Interest.count } do
      post interest_path, params: { website: "spam.example", interest: { email_address: "bot@example.com" } }
    end
    assert_redirected_to interest_path
  end

  test "admins see the list, make an account from it, and remove people" do
    interest = Interest.record!(email_address: "ana@example.com", role: "player", note: "Hi")
    sign_in_as identities(:gwen)
    identities(:gwen).update!(admin: true)

    get admin_interests_path
    assert_select "option[selected][value=early_access]", 1, "Early access unless the admin picks another plan"
    assert_select "td", /ana@example.com/
    assert_select "td", "Mostly play"

    assert_difference -> { Identity.count } do
      post admin_interest_account_path(interest), params: { identity: { plan: "free" } }
    end
    assert_equal "free", Identity.find_by!(email_address: "ana@example.com").plan
    follow_redirect!
    assert_select "td", /Has one, on Free/

    assert_difference -> { Interest.count }, -1 do
      delete admin_interest_path(interest)
    end
  end

  test "the admin list pages 50 at a time and searches email and note" do
    Interest.insert_all(55.times.map { |i| { email_address: "fan#{i}@example.com", note: (i == 7 ? "We play in Lisbon" : nil), created_at: i.hours.ago, updated_at: i.hours.ago } })
    identities(:gwen).update!(admin: true)
    sign_in_as identities(:gwen)

    get admin_interests_path
    assert_select "tbody tr", 50
    assert_select ".admin-pages .series-nav a[href*='page=2']"
    assert_select ".admin-pages .pagy.info", /51 of 55|1-50 of 55/
    assert_no_match "&lt;nav", response.body, "pagy's HTML isn't escaped"

    get admin_interests_path(page: 2)
    assert_select "tbody tr", 5

    get admin_interests_path(q: "LISBON")
    assert_select "tbody tr", 1
    assert_select "td", /fan7@example.com/
    assert_select ".admin-pages .series-nav", 0, "one page, no page links"

    get admin_interests_path(q: "nobody-here")
    assert_select ".empty", /No one matches/
  end

  test "the admin list filters by how they'd play, and long text can show in full" do
    Interest.record!(email_address: "gm@example.com", role: "gm", note: "A long note " * 30)
    Interest.record!(email_address: "player@example.com", role: "player")
    Interest.record!(email_address: "quiet@example.com")
    identities(:gwen).update!(admin: true)
    sign_in_as identities(:gwen)

    get admin_interests_path(role: "gm")
    assert_select "tbody tr", 1
    assert_select "select[name=role] option[selected][value=gm]"
    assert_select ".admin-truncate--note[data-controller=truncated-tip]", /A long note/

    get admin_interests_path(role: "none")
    assert_select "tbody tr", 1
    assert_select "td", /quiet@example.com/

    get admin_interests_path(role: "nonsense")
    assert_select "tbody tr", 3
  end

  test "accounts and campaigns search too" do
    identities(:gwen).update!(admin: true)
    sign_in_as identities(:gwen)

    get admin_identities_path(q: identities(:pip).email_address)
    assert_select "tbody tr", 1

    get admin_campaigns_path(q: "no campaign is called this")
    assert_select "tbody tr", 0
  end

  test "the list is admins only" do
    sign_in_as identities(:pip)
    get admin_interests_path
    assert_response :not_found
  end
end
