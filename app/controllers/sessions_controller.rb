# Sign in / sign up in one step: enter an email, get a code. New emails get an
# Identity when their first code is redeemed.
class SessionsController < ApplicationController
  include PendingAuthentication

  require_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
  end

  def create
    magic_link = MagicLink.new(email_address: params.expect(:email_address))

    if magic_link.save
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
      set_pending_authentication(magic_link)
      flash[:magic_link_code] = magic_link.code if Rails.env.development?
      redirect_to session_magic_link_path
    else
      redirect_to new_session_path, alert: "That doesn't look like an email address."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Signed out."
  end
end
