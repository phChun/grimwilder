# Step 1 of adding a passkey: creation options for the signed-in identity.
class Passkeys::ChallengesController < ApplicationController
  require_authentication

  def create
    identity = Current.identity
    options = WebAuthn::Credential.options_for_create(
      user: { id: identity.webauthn_user_handle!, name: identity.email_address, display_name: identity.display_name },
      exclude: identity.passkeys.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "required" }
    )
    session[:passkey_registration_challenge] = options.challenge
    render json: options
  end
end
