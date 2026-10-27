# Sessions (pg. 32): the history, for everyone at the table; starting one
# (who's here, "Previously on…") and editing the recap afterwards, for the GM.
class Campaigns::PlaySessionsController < ApplicationController
  include CampaignScoped

  before_action :require_gm, except: %i[ index show ]
  before_action :set_form, only: %i[ new create ]

  def index
    @sessions = Current.campaign.play_sessions.includes(:scenes, :characters).order(number: :desc)
    @between = between_sessions
    # Each session's own log, for its fold: { session id => { scene id => rolls } }.
    @logs = Current.campaign.rolls.where(play_session: @sessions).visible_to(Current.membership).includes(:identity, :pool).order(:created_at, :id)
      .group_by(&:play_session_id).transform_values { _1.group_by(&:scene_id) }
  end

  def show
    @session = Current.campaign.play_sessions.find(params[:id])
    @rolls = @session.rolls.visible_to(Current.membership).includes(:identity, :pool).order(:created_at, :id).group_by(&:scene_id)
  end

  def new
  end

  def create
    characters = Current.campaign.characters.played.active.where(id: Array(params[:character_ids]).compact_blank).to_a
    session = PlaySession.start!(Current.campaign, characters: characters, recap: params[:recap], by: Current.identity)
    back_to_table(notice: "#{session.title} begins.")
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
    # The log made outside any session (rests, downtime, rolls, notes), grouped
    # by the session that came after it, oldest first; nil holds what's come
    # since the last one. Rolls made during a session carry it, so these are
    # the ones without.
    def between_sessions
      by_start = @sessions.sort_by(&:number)
      Current.campaign.rolls.where(play_session_id: nil).visible_to(Current.membership).includes(:identity, :pool).order(:created_at, :id)
        .group_by { |roll| by_start.find { _1.started_at > roll.created_at } }
    end

    def set_form
      @characters = Current.campaign.characters.played.active.includes(:identity).ordered
      @previous = Current.campaign.play_sessions.includes(:scenes).ordered.last
      @number = @previous&.number.to_i + 1
    end
end
