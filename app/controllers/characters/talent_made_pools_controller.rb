# A pool a talent makes when it's used (Talent::MadePool), from its card:
# Echo's duplicate, Awaken's living feature, Soothsayer's Spirit pool. The
# owner makes it; it lasts the scene or session.
class Characters::TalentMadePoolsController < ApplicationController
  include CharacterScoped

  before_action :refuse_when_campaign_archived

  def create
    pool = @character.make_talent_pool!(params[:talent_id], params.expect(:made), by: Current.identity, name: params[:name])
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}"), notice: "#{pool.name} is ready: #{pool.size}d."
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}"), alert: error.message
  end
end
