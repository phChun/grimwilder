# Sign in / sign up in one step: enter an email, get a code. New emails get an
# Identity when their first code is redeemed, unless sign-ups are closed
# (Identity.signups_open?) and they weren't invited to a campaign.
class SessionsController < ApplicationController
  include PendingAuthentication

  require_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
  end

  def create
    magic_link = MagicLink.new(email_address: params.expect(:email_address))

    if magic_link.invalid?
      redirect_to new_session_path, alert: "That doesn't look like an email address."
    else
      # With sign-ups closed an unknown address gets no code, but the same next
      # page, so this still never says whether an account exists.
      send_code(magic_link) if Identity.may_sign_in?(magic_link.email_address, invited: invited?)
      set_pending_authentication(magic_link.email_address, expires_at: magic_link.expires_at)
      redirect_to session_magic_link_path
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Signed out."
  end

  private
    def send_code(magic_link)
      magic_link.save!
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
      flash[:magic_link_code] = magic_link.code if Rails.env.development?
    end
end
