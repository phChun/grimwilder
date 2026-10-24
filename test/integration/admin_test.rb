require "test_helper"

# /admin: only identities with admin set get in; everyone else gets a 404.
class AdminTest < ActionDispatch::IntegrationTest
  test "signing in comes first" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "anyone else gets a 404, and no Admin tab" do
    sign_in_as identities(:gwen)

    get campaigns_path
    assert_select ".tabs a", text: "Admin", count: 0

    [ admin_root_path, admin_identities_path, admin_campaigns_path ].each do |path|
      get path
      assert_response :not_found
    end

    assert_no_difference -> { Identity.count } do
      post admin_identities_path, params: { identity: { email_address: "new@example.com" } }
    end
    assert_response :not_found
  end

  test "an admin sees the stats, accounts and campaigns" do
    sign_in_as identities(:ada)

    get admin_root_path
    assert_response :success
    assert_select ".tabs a[aria-current=page]", text: "Admin"
    assert_select ".admin-stats__label", text: "Accounts"

    get admin_identities_path
    assert_response :success
    assert_select "td", text: identities(:pip).email_address

    get admin_campaigns_path
    assert_response :success
    assert_select "td", text: campaigns(:bramblewood).name
  end

  test "last sign-in outlasts signing out" do
    sign_in_as identities(:pip)
    signed_in_at = identities(:pip).reload.last_signed_in_at
    assert signed_in_at
    sign_out

    sign_in_as identities(:ada)
    get admin_identities_path
    assert_select "tr", text: /#{identities(:pip).email_address}/ do
      assert_select "td", text: "Never", count: 0
    end

    get admin_root_path
    assert_select ".list__item strong", text: "Pip"
  end

  test "an admin makes an account, which can then sign in with sign-ups closed" do
    was_open = Rails.configuration.x.signups_open
    Rails.configuration.x.signups_open = false
    sign_in_as identities(:ada)

    assert_difference -> { Identity.count }, 1 do
      post admin_identities_path, params: { identity: { email_address: " New@Example.com ", name: "Newt" } }
    end
    assert_redirected_to admin_identities_path
    assert_equal "Newt", Identity.find_by(email_address: "new@example.com").name
    assert Identity.may_sign_in?("new@example.com")

    assert_no_difference -> { Identity.count } do
      post admin_identities_path, params: { identity: { email_address: "new@example.com" } }
    end
    assert_equal "new@example.com already has an account.", flash[:notice]

    assert_no_difference -> { Identity.count } do
      post admin_identities_path, params: { identity: { email_address: "not an email" } }
    end
    assert_response :unprocessable_entity
  ensure
    Rails.configuration.x.signups_open = was_open
  end
end
