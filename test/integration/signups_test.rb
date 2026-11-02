require "test_helper"

# ALLOW_SIGNUPS=false (config.x.signups_open): existing accounts still sign in,
# new emails only get an account through a campaign's invite link, and anyone
# else is told sign-ups are closed.
class SignupsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @was_open = Rails.configuration.x.signups_open
    Rails.configuration.x.signups_open = false
  end

  teardown { Rails.configuration.x.signups_open = @was_open }

  test "a new email gets no code, and is told sign-ups are closed" do
    get new_session_path
    assert_select ".page-header__lede", /invite-only/

    assert_no_enqueued_emails do
      post session_path, params: { email_address: "nobody-yet@example.com" }
    end
    assert_redirected_to new_session_path
    assert_equal "We're not taking new sign-ups right now. If your GM sent you an invite link, open it first.", flash[:alert]
    assert_not MagicLink.exists?(email_address: "nobody-yet@example.com")
  end

  test "an existing account still signs in" do
    assert_enqueued_emails 1 do
      post session_path, params: { email_address: identities(:pip).email_address.upcase }
    end
    post session_magic_link_path, params: { code: MagicLink.order(:id).last.code }
    assert cookies[:session_token].present?
  end

  test "an invite link lets a new player sign up, until the GM resets it" do
    campaign = campaigns(:bramblewood)
    get join_path(campaign.join_code)

    get new_session_path
    assert_select ".page-header__lede", /Entering your email creates your account/
    post session_path, params: { email_address: "newplayer@example.com" }
    assert_difference -> { Identity.count }, 1 do
      post session_magic_link_path, params: { code: MagicLink.order(:id).last.code }
    end
    sign_out

    get join_path(campaign.join_code)
    campaign.update!(join_code: "reset-code-0000")
    assert_no_enqueued_emails do
      post session_path, params: { email_address: "latecomer@example.com" }
    end
    assert_redirected_to new_session_path
  end

  test "an invite link turned off after it was opened lets no one sign up" do
    campaign = campaigns(:bramblewood)
    get join_path(campaign.join_code)
    campaign.update!(join_link_enabled: false)
    assert_no_enqueued_emails do
      post session_path, params: { email_address: "newplayer@example.com" }
    end
    assert_redirected_to new_session_path
  end

  test "a code sent while sign-ups were open doesn't make an account after they close" do
    Rails.configuration.x.signups_open = true
    post session_path, params: { email_address: "early@example.com" }
    Rails.configuration.x.signups_open = false

    assert_no_difference -> { Identity.count } do
      post session_magic_link_path, params: { code: MagicLink.order(:id).last.code }
    end
    assert_redirected_to session_magic_link_path
  end
end
