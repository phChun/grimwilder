class Characters::ConditionsController < ApplicationController
  include CharacterScoped

  def create
    @character.add_condition!(params.expect(:condition))
    redirect_to character_path(@character, anchor: "damage")
  end

  def destroy
    @character.remove_condition!(params[:id])
    redirect_to character_path(@character, anchor: "damage")
  end
end
