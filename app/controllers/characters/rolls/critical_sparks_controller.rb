# A critical where none of the effects fit gives spark instead (pg. 10).
class Characters::Rolls::CriticalSparksController < ApplicationController
  include CharacterScoped

  def create
    roll = @character.rolls.find(params[:roll_id])
    @character.take_spark_for_critical!(roll)
    redirect_to character_roll_path(@character, roll)
  rescue ArgumentError => error
    redirect_to character_roll_path(@character, roll), alert: error.message
  end
end
