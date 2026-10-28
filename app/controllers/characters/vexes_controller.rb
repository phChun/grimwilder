# Vex (pg. 30) on the sheet's Harm card: take it, with the response and what
# it's aimed at, or let it pass. The owner or the campaign's GM, like harm.
class Characters::VexesController < ApplicationController
  include CharacterDamage

  def create
    @character.take_vex(params.expect(:vex), subject: params[:subject])
    @character.save!
    back_to_damage
  end

  def destroy
    @character.shake_off_vex
    @character.save!
    back_to_damage
  end
end
