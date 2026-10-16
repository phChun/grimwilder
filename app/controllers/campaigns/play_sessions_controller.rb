# Starting a session (pg. 31): who's here, and "Previously on…". GM only.
class Campaigns::PlaySessionsController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_form, only: %i[ new create ]

  def new
  end

  def create
    characters = Current.campaign.characters.where(id: Array(params[:character_ids]).compact_blank).to_a
    session = PlaySession.start!(Current.campaign, characters: characters, recap: params[:recap], by: Current.identity)
    redirect_to campaign_path(Current.campaign), notice: "#{session.title} begins."
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_form
      @characters = Current.campaign.characters.includes(:identity).ordered
      @previous = Current.campaign.play_sessions.ordered.last
      @number = @previous&.number.to_i + 1
    end
end
