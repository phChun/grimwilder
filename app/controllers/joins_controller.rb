# Joining a campaign through its shareable link: /join/:code.
class JoinsController < ApplicationController
  before_action :set_campaign
  require_authentication only: :create

  def show
    @membership = Current.identity&.membership_in(@campaign)
    session[:return_to_after_authenticating] = request.url unless authenticated?
  end

  def create
    @campaign.memberships.find_or_create_by!(identity: Current.identity)
    redirect_to @campaign, notice: "Welcome to #{@campaign.name}."
  end

  private
    def set_campaign
      @campaign = Campaign.find_by!(join_code: params[:code])
    end
end
