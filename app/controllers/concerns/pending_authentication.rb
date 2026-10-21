# Remembers which email address is waiting for a code, in a signed cookie that
# expires with the code. Redeeming a code requires this cookie, so a code is
# only good in the browser that asked for it.
module PendingAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :email_address_pending_authentication, :invited?
  end

  private
    def set_pending_authentication(email_address, expires_at:)
      cookies[:pending_authentication] = {
        value: pending_authentication_verifier.generate(email_address, expires_at: expires_at),
        expires: expires_at,
        httponly: true,
        same_site: :lax
      }
    end

    def email_address_pending_authentication
      pending_authentication_verifier.verified(cookies[:pending_authentication])
    end

    def clear_pending_authentication
      cookies.delete(:pending_authentication)
    end

    # Someone who opened a campaign's invite link (JoinsController#show) may sign
    # up even while sign-ups are closed, as long as the link still works (the
    # GM resetting it takes that back).
    def invited?
      session[:invite_code].present? && Campaign.exists?(join_code: session[:invite_code])
    end

    def pending_authentication_verifier
      Rails.application.message_verifier(:pending_authentication)
    end
end
