# Redeems an emailed code. The code must match the email address waiting in
# this browser's pending-authentication cookie.
class Sessions::MagicLinksController < ApplicationController
  include PendingAuthentication

  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Too many attempts. Try again in 15 minutes." }
  before_action :require_pending_authentication

  def show
  end

  def create
    magic_link = MagicLink.consume(params.expect(:code), email_address: email_address_pending_authentication)

    # A code sent before sign-ups closed doesn't open a new account after.
    if magic_link && Identity.may_sign_in?(magic_link.email_address, invited: invited?)
      clear_pending_authentication
      start_new_session_for Identity.find_or_create_for_sign_in!(magic_link.email_address)
      redirect_to after_authentication_url
    else
      redirect_to session_magic_link_path, alert: "That code didn't work. Check it, or ask for a new one."
    end
  end

  private
    def require_pending_authentication
      unless email_address_pending_authentication
        redirect_to new_session_path, alert: "Enter your email to get a sign-in code."
      end
    end
end
