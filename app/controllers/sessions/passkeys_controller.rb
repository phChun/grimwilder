# Step 2 of signing in with a passkey: verify the signed challenge.
class Sessions::PasskeysController < ApplicationController
  include PasskeyCredentialParams

  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render json: { error: "Too many attempts. Try again in a few minutes." }, status: :too_many_requests }

  def create
    credential = WebAuthn::Credential.from_get(passkey_credential_params)
    passkey = Passkey.find_by(external_id: credential.id)
    challenge = session.delete(:passkey_authentication_challenge)

    if passkey.nil? || challenge.blank?
      render json: { error: "That passkey isn't registered here. Sign in with your email instead." }, status: :unprocessable_entity
    elsif credential.user_handle.present? && credential.user_handle != passkey.identity.webauthn_user_handle
      render json: { error: "That passkey doesn't match its account." }, status: :unprocessable_entity
    else
      credential.verify(challenge, public_key: passkey.public_key, sign_count: passkey.sign_count, user_verification: true)
      passkey.record_use!(credential.sign_count)
      start_new_session_for passkey.identity
      render json: { location: after_authentication_url }
    end
  rescue WebAuthn::Error => error
    Rails.logger.info "Passkey sign-in failed: #{error.class}: #{error.message}"
    render json: { error: "That passkey couldn't be verified. Try again, or sign in with your email." }, status: :unprocessable_entity
  end
end
