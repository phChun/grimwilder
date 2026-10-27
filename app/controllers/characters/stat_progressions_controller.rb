# The optional stat progression rule (pg. 175), from the sheet's Talents:
# the owner gives up a talent slot for +1 to a stat, or takes it back.
class Characters::StatProgressionsController < ApplicationController
  include CharacterScoped

  def create
    @character.progress_stat!(params.expect(:stat), by: Current.identity)
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talents"), notice: "#{@character.short_name} gives up a talent for +1 #{@character.stat_progression.capitalize}."
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talents"), alert: error.message
  end

  def destroy
    @character.undo_stat_progression!
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talents"), notice: "#{@character.short_name} has the talent slot back."
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talents"), alert: error.message
  end
end
