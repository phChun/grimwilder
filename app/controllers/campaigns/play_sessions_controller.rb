# Sessions (pg. 31): the history, for everyone at the table; starting one
# (who's here, "Previously on…") and editing the recap afterwards, for the GM.
class Campaigns::PlaySessionsController < ApplicationController
  include CampaignScoped

  before_action :require_gm, except: %i[ index show ]
  before_action :set_form, only: %i[ new create ]

  def index
    @sessions = Current.campaign.play_sessions.includes(:scenes, :characters).order(number: :desc)
    @before = Current.campaign.rolls.where(play_session_id: nil).table_log(Current.membership)
  end

  def show
    @session = Current.campaign.play_sessions.find(params[:id])
    @rolls = @session.rolls.visible_to(Current.membership).includes(:identity, :pool).order(:created_at, :id).group_by(&:scene_id)
  end

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

  def update
    session = Current.campaign.play_sessions.find(params[:id])
    session.update!(params.expect(play_session: [ :recap, :notes ]))
    redirect_to campaign_play_session_path(Current.campaign, session), notice: "Saved."
  end

  private
    def set_form
      @characters = Current.campaign.characters.includes(:identity).ordered
      @previous = Current.campaign.play_sessions.includes(:scenes, moments: :character).ordered.last
      @number = @previous&.number.to_i + 1
    end
end
