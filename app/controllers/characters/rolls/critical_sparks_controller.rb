# A critical where none of the effects fit gives spark instead (pg. 10). The
# button sits on the sheet's "Last roll" card.
class Characters::Rolls::CriticalSparksController < ApplicationController
  include CharacterScoped

  def create
    @character.take_spark_for_critical!(@character.rolls.find(params[:roll_id]))
    redirect_to @character
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end
end
