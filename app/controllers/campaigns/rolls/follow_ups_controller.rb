# Talents that change a roll after it's made (Roll::FollowUps): Luck's bonus
# die, Blessed's re-roll, an ally's Inspiration. The page lists what the
# viewer's characters can do to it (the GM's, everyone's), as its own page or
# in the modal from the roll toast and the log.
class Campaigns::Rolls::FollowUpsController < ApplicationController
  include CampaignScoped
  before_action :refuse_when_on_hold

  before_action :set_roll

  def new
    @options = @roll.follow_ups_for(characters)
  end

  def create
    @roll.follow_up!(characters.find(params.expect(:character_id)), params.expect(:follow_up), by: Current.identity, die: params[:die], omen: params[:omen])
    redirect_back_or_to table_path_for_viewer, status: :see_other
  rescue ArgumentError => error
    redirect_back_or_to table_path_for_viewer, alert: error.message, status: :see_other
  end

  private
    def set_roll
      @roll = Current.campaign.rolls.visible_to(Current.membership).find(params[:roll_id])
    end

    def characters
      Current.membership.follow_up_characters
    end
end
