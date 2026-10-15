# Step 2 of adding a passkey (create), and removing one (destroy).
class PasskeysController < ApplicationController
  include PasskeyCredentialParams

  require_authentication

  def create
    credential = WebAuthn::Credential.from_create(passkey_credential_params)
    credential.verify(session.delete(:passkey_registration_challenge), user_verification: true)

    Current.identity.passkeys.create!(
      external_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      name: passkey_name
    )

    flash[:notice] = "Passkey added. Next time, sign in with it."
    render json: { location: profile_path }, status: :created
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid => error
    Rails.logger.info "Passkey registration failed: #{error.class}: #{error.message}"
    render json: { error: "That passkey couldn't be added. Try again." }, status: :unprocessable_entity
  end

  def destroy
    Current.identity.passkeys.find(params[:id]).destroy
    redirect_to profile_path, notice: "Passkey removed."
  end

  private
    def passkey_name
      params[:name].to_s.squish.presence&.truncate(80) || "Passkey added #{Date.current.to_fs(:long)}"
    end
end
