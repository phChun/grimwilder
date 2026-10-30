# Step 1 of signing in with a passkey: hand the browser a challenge to sign.
# No account is named (discoverable credentials), so the browser offers every
# Grimwilder passkey on the device.
class Sessions::PasskeyChallengesController < ApplicationController
  require_unauthenticated_access
  rate_limit to: 20, within: 3.minutes, only: :create, with: -> { render json: { error: "Too many attempts. Try again in a few minutes." }, status: :too_many_requests }

  def create
    options = WebAuthn::Credential.options_for_get(user_verification: "required")
    session[:passkey_authentication_challenge] = options.challenge
    render json: options
  end
end
