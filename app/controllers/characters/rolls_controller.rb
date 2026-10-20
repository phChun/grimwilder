# Action and defense rolls from the sheet. The setup folds open on the stat
# card itself; the server rolls, then the sheet shows the result in its "Last
# roll" card. Rolls of a seated character also land in the campaign's log for
# the whole table.
class Characters::RollsController < ApplicationController
  include CharacterScoped

  def create
    @character.roll!(params.expect(:stat), by: Current.identity, mode: params[:mode].presence || "action",
      spend_spark: params[:spark].to_i, help: params[:help].to_i, thorns: params[:thorns].to_i, assists: assists)
    redirect_to @character
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end

  private
    # The model checks that every assist is seated alongside this character.
    def assists
      Character.where(id: Array(params[:assists]).compact_blank).to_a
    end
end
