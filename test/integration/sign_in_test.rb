require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "a new email signs up with a code, then picks a name" do
    assert_enqueued_emails 1 do
      post session_path, params: { email_address: "newcomer@example.com" }
    end
    assert_redirected_to session_magic_link_path
    assert_no_difference -> { Identity.count }, "asking for a code must not create an account" do
      follow_redirect!
    end

    code = MagicLink.find_by!(email_address: "newcomer@example.com").code
    assert_difference -> { Identity.count }, 1 do
      post session_magic_link_path, params: { code: code }
    end
    assert_redirected_to profile_path

    patch profile_path, params: { identity: { name: "Newcomer" } }
    assert_redirected_to campaigns_path
    assert_equal "Newcomer", Identity.find_by!(email_address: "newcomer@example.com").name
  end

  test "an existing identity signs in and returns to where it was going" do
    get campaign_path(campaigns(:bramblewood))
    assert_redirected_to new_session_path

    sign_in_as identities(:gwen)
    assert_redirected_to campaign_path(campaigns(:bramblewood))
  end

  test "a wrong code doesn't sign in" do
    post session_path, params: { email_address: identities(:gwen).email_address }
    post session_magic_link_path, params: { code: "WRONG1" }

    assert_redirected_to session_magic_link_path
    assert cookies[:session_token].blank?
  end

  test "a code only works in the browser that asked for it" do
    link = MagicLink.create!(email_address: identities(:gwen).email_address)

    post session_magic_link_path, params: { code: link.code }
    assert_redirected_to new_session_path
    assert MagicLink.exists?(link.id)
  end

  test "signing out ends the session" do
    sign_in_as identities(:gwen)
    sign_out

    get profile_path
    assert_redirected_to new_session_path
  end

  test "the play tools don't need an account" do
    get roll_path
    assert_response :success
    assert_select "a[href=?]", new_session_path
  end

  test "a sign-in lasts six hours" do
    sign_in_as identities(:gwen)
    get campaigns_path
    assert_response :success

    session_record = identities(:gwen).sessions.last
    travel Session::LIFETIME + 1.minute do
      get campaigns_path
      assert_redirected_to new_session_path
      assert_nil Session.resume(session_record.signed_id), "refused even if a browser keeps the cookie"

      Session.cleanup
      assert_not Session.exists?(session_record.id)
    end
  end
end
