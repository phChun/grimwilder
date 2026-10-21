# Adding and clearing conditions on the sheet: the owner's or the GM's.
class Characters::ConditionsController < ApplicationController
  include CharacterDamage

  def create
    @character.add_condition!(params[:condition], lasts: params[:lasts], dice: params[:dice])
    back_to_damage
  rescue ArgumentError => error
    back_to_damage(alert: error.message)
  end

  def destroy
    @character.remove_condition!(params[:id])
    back_to_damage
  end
end
