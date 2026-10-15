require "test_helper"

class PasskeyTest < ActionDispatch::IntegrationTest
  setup do
    @client = WebAuthn::FakeClient.new("http://www.example.com")
  end

  test "add a passkey, then sign in with it" do
    sign_in_as identities(:gwen)

    post passkeys_challenge_path, as: :json
    options = response.parsed_body
    assert_equal "required", options.dig("authenticatorSelection", "residentKey")

    credential = @client.create(challenge: options["challenge"], user_verified: true)
    assert_difference -> { identities(:gwen).passkeys.count }, 1 do
      post passkeys_path, params: { credential: credential }, as: :json
    end
    assert_response :created

    sign_out

    post session_passkey_challenge_path, as: :json
    assertion = @client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post session_passkey_path, params: { credential: assertion }, as: :json

    assert_response :success
    assert_equal campaigns_path, response.parsed_body["location"]
    assert_not_nil identities(:gwen).passkeys.first.last_used_at
  end

  test "an unknown passkey is refused" do
    post session_passkey_challenge_path, as: :json
    stray = WebAuthn::FakeClient.new("http://www.example.com")
    stray.create(user_verified: true)
    assertion = stray.get(challenge: response.parsed_body["challenge"], user_verified: true)

    post session_passkey_path, params: { credential: assertion }, as: :json
    assert_response :unprocessable_entity
    assert cookies[:session_token].blank?
  end

  test "remove a passkey" do
    passkey = identities(:gwen).passkeys.create!(external_id: "abc", public_key: "key", name: "Laptop")
    sign_in_as identities(:gwen)

    delete passkey_path(passkey)
    assert_redirected_to profile_path
    assert_not Passkey.exists?(passkey.id)
  end
end
