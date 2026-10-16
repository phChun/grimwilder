# Ending a session: XP for everyone there, double for a standout session. GM only.
class Campaigns::PlaySessions::EndingsController < ApplicationController
  include CampaignScoped

  before_action :require_gm
  before_action :set_session

  def new
  end

  def create
    levelled = @session.end!(by: Current.identity, standout: params[:standout] == "1", notes: params[:notes], clear: Array(params[:clear]))
    redirect_to campaign_path(Current.campaign), notice: [ "#{@session.title} ends.", *levelled.map { "#{_1.name} reached level #{_1.level}." } ].join(" ")
  rescue ArgumentError => error
    redirect_to campaign_path(Current.campaign), alert: error.message
  end

  private
    def set_session
      @session = Current.campaign.play_sessions.find(params[:play_session_id])
    end
end
