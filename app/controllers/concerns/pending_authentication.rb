# Remembers which email address is waiting for a code, in a signed cookie that
# expires with the code. Redeeming a code requires this cookie, so a code is
# only good in the browser that asked for it.
module PendingAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :email_address_pending_authentication
  end

  private
    def set_pending_authentication(magic_link)
      cookies[:pending_authentication] = {
        value: pending_authentication_verifier.generate(magic_link.email_address, expires_at: magic_link.expires_at),
        expires: magic_link.expires_at,
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

    def pending_authentication_verifier
      Rails.application.message_verifier(:pending_authentication)
    end
end
