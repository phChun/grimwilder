# Sessions (pg. 32): the history, for everyone at the table; starting one
# (who's here, "Previously on…") and editing the recap afterwards, for the GM.
class Campaigns::PlaySessionsController < ApplicationController
  include CampaignScoped
  before_action :refuse_when_on_hold, only: %i[ new create ] # editing a recap or notes is fine

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
    block = Current.campaign.scene_blocks.find_by(id: params[:scene_block_id])
    session = PlaySession.start!(Current.campaign, characters: characters, recap: params[:recap], block: block, by: Current.identity)
    back_to_table(notice: "#{session.title} begins.")
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  # The recap and notes, from the session's page; or the block it's playing,
  # from the new-scene picker (the players headed somewhere else), which it
  # goes back to.
  def update
    session = Current.campaign.play_sessions.find(params[:id])
    if params.dig(:play_session, :scene_block_id)
      session.update!(scene_block: Current.campaign.scene_blocks.find_by(id: params[:play_session][:scene_block_id]))
      return redirect_to(new_campaign_scene_path(Current.campaign))
    end

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
      @blocks = Current.campaign.scene_blocks.ordered.includes(:scene_plans)
    end
end
