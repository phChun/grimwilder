# Rolls a condition that's a pool ("4d poisoned") from the sheet's Harm card:
# the owner or the GM.
class Characters::Conditions::RollsController < ApplicationController
  include CharacterDamage

  def create
    @character.roll_condition!(params[:condition_id], by: Current.identity)
    back_to_damage(note: false)
  rescue ArgumentError => error
    back_to_damage(note: false, alert: error.message)
  end
end
