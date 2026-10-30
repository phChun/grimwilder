# The "I'm interested" form (/interest) for people who can't sign up while
# sign-ups are closed. Public. A filled-in honeypot field (website) is taken
# as a bot: it's thanked and nothing is saved.
class InterestsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_interest_path, alert: "Too many tries. Try again in an hour." }

  def new
    @interest = Interest.new
  end

  def create
    unless params[:website].present?
      Interest.record!(**params.expect(interest: %i[ email_address role note ]).to_h.symbolize_keys)
    end
    redirect_to interest_path
  rescue ActiveRecord::RecordInvalid => error
    @interest = error.record
    render :new, status: :unprocessable_entity
  end

  def show
  end
end
