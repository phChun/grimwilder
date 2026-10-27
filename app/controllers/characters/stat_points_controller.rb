# Level 0 (optional rule, pg. 177): reaching level 1, the owner adds the last
# stat point (Character::Advancement#add_stat_point!).
class Characters::StatPointsController < ApplicationController
  include CharacterScoped

  def create
    @character.add_stat_point!(params.expect(:stat), by: Current.identity)
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "stats")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "stats"), alert: error.message
  end
end
