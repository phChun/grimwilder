# Joining a campaign through its shareable link: /join/:code.
class JoinsController < ApplicationController
  before_action :set_campaign
  require_authentication only: :create

  def show
    @membership = Current.identity&.membership_in(@campaign)
    @blocked = !@membership && @campaign.blocked?(Current.identity)
    # Joining needs room in their plan (Identity::Plans).
    @no_room = authenticated? && !@membership && !Current.identity.room_to_play?
    unless authenticated?
      session[:return_to_after_authenticating] = request.url
      session[:invite_code] = @campaign.join_code if @campaign.join_link_enabled? # lets them sign up while sign-ups are closed
    end
  end

  def create
    unless @campaign.joinable? || Current.identity.membership_in(@campaign)
      return redirect_to join_path(@campaign.join_code), alert: "#{@campaign.name} isn't taking new players through this link."
    end

    @campaign.memberships.find_or_create_by!(identity: Current.identity)
    redirect_to @campaign, notice: "Welcome to #{@campaign.name}."
  end

  private
    def set_campaign
      @campaign = Campaign.find_by!(join_code: params[:code])
    end
end
