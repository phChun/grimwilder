class Characters::ConditionsController < ApplicationController
  include CharacterScoped

  before_action { @character.changed_by = Current.identity }

  def create
    @character.add_condition!(params.expect(:condition), lasts: params[:lasts])
    redirect_to character_path(@character, anchor: "damage")
  end

  def destroy
    @character.remove_condition!(params[:id])
    redirect_to character_path(@character, anchor: "damage")
  end
end
