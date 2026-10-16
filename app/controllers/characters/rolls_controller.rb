# Action and defense rolls from the sheet: set up the roll (spark, help,
# situational thorns), roll it on the server, then show the result. Rolls of a
# seated character land in the campaign's log for the whole table.
class Characters::RollsController < ApplicationController
  include CharacterScoped

  def new
    @stat = params[:stat].presence_in(Grimwild::STATS)
    redirect_to @character, alert: "Pick Brawn, Agility, Wits or Presence." unless @stat
  end

  def create
    roll = @character.roll!(params.expect(:stat), by: Current.identity, mode: params[:mode].presence || "action",
      spend_spark: params[:spark].to_i, help: params[:help].to_i, thorns: params[:thorns].to_i)
    redirect_to character_roll_path(@character, roll)
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end

  def show
    @roll = @character.rolls.where(kind: Character::Rolling::MODES).find(params[:id])
  end
end
