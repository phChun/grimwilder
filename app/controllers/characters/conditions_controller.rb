# Adding and clearing conditions on the sheet: the owner's or the GM's.
class Characters::ConditionsController < ApplicationController
  include CharacterDamage

  def create
    @character.add_condition!(params.expect(:condition), lasts: params[:lasts])
    back_to_damage
  end

  def destroy
    @character.remove_condition!(params[:id])
    back_to_damage
  end
end
