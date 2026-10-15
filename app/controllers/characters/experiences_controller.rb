# +1 XP after a session; filling the boxes levels the character up.
class Characters::ExperiencesController < ApplicationController
  include CharacterScoped

  def create
    if @character.gain_xp!
      redirect_to new_character_talent_path(@character), notice: "Level #{@character.level}! Choose a new talent."
    else
      redirect_to @character
    end
  end
end
