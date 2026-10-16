# Best moments from last session (pg. 31): players for their own characters,
# the GM for anyone's.
class Campaigns::PlaySessions::MomentsController < ApplicationController
  include CampaignScoped

  def create
    session = Current.campaign.play_sessions.find(params[:play_session_id])
    character = Current.campaign.characters.find(params[:character_id])
    return head :forbidden unless PlaySession::Moment.writable_by?(Current.identity, character, Current.campaign)

    moment = session.moments.create(character: character, identity: Current.identity, text: params[:text])
    target = params[:return_to] == "session" ? campaign_play_session_path(Current.campaign, session, anchor: "moments") : campaign_path(Current.campaign)
    redirect_to target, (moment.persisted? ? { notice: "Moment saved." } : { alert: moment.errors.full_messages.to_sentence })
  end
end
