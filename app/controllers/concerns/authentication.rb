# Passwordless authentication: an emailed code (MagicLink) or a passkey starts
# a Session, remembered by a signed, http-only cookie.
#
# Every request resumes the session if there is one, so pages can show who is
# signed in. The play tools stay public; controllers that need a signed-in
# identity call `require_authentication`.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :authenticated?
  end

  class_methods do
    def require_authentication(**options)
      before_action :request_authentication, **options, unless: :authenticated?
    end

    def require_unauthenticated_access(**options)
      before_action :redirect_authenticated_identity, **options
    end
  end

  private
    def authenticated?
      Current.identity.present?
    end

    def resume_session
      if session_record = Session.find_signed(cookies.signed[:session_token])
        Current.session = session_record
      end
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url if request.get? || request.head?
      redirect_to new_session_path
    end

    def redirect_authenticated_identity
      redirect_to after_authentication_url if authenticated?
    end

    def after_authentication_url
      if !Current.identity.profile_complete?
        profile_path
      else
        session.delete(:return_to_after_authenticating) || campaigns_path
      end
    end

    def start_new_session_for(identity)
      reset_session_preserving_return_to
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session_record|
        Current.session = session_record
        cookies.signed.permanent[:session_token] = { value: session_record.signed_id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_token)
      reset_session
    end

    # Rotate the Rails session on sign-in (session fixation) but keep where the
    # person was heading.
    def reset_session_preserving_return_to
      return_to = session[:return_to_after_authenticating]
      reset_session
      session[:return_to_after_authenticating] = return_to if return_to
    end
end
