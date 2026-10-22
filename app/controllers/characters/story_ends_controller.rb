# A character's story ending (Character::Farewell): the owner marks them
# fallen or retired, with a farewell line, or brings them back to play.
class Characters::StoryEndsController < ApplicationController
  include CharacterScoped

  def create
    @character.end_story!(params.expect(:status), by: Current.identity, farewell: params[:farewell])
    redirect_to @character, notice: @character.fallen? ? "#{@character.short_name} has fallen." : "#{@character.short_name} retires."
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end

  def destroy
    @character.return_to_play!(by: Current.identity)
    redirect_to @character, notice: "#{@character.short_name} returns to play."
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end
end
