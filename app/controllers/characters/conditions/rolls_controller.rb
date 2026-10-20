# Rolls a condition that's a pool ("4d poisoned") from the sheet's Harm card.
class Characters::Conditions::RollsController < ApplicationController
  include CharacterScoped

  def create
    @character.roll_condition!(params[:condition_id], by: Current.identity)
    redirect_to character_path(@character, anchor: "damage")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "damage"), alert: error.message
  end
end
