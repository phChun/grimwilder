# Push yourself (pg. 21) from a talent's card: the owner marks a stat after
# using the talent; a stat already marked takes harm instead.
class Characters::TalentPushesController < ApplicationController
  include CharacterScoped

  def create
    took = @character.push!(params.expect(:stat), talent_key: params[:talent_id], by: Current.identity)
    @character.broadcast_refresh_later
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}"), notice: "#{@character.short_name} #{took}."
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}"), alert: error.message
  end
end
