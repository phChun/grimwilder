# The owner archives a character (Character::Archive), taking them out of a
# table they're playing at, or brings them back. Both return to the
# Characters page unless the request says otherwise.
class Characters::ArchivesController < ApplicationController
  include CharacterScoped

  def create
    @character.archive!(by: Current.identity)
    redirect_to characters_path, notice: "#{@character.short_name} is archived."
  rescue ArgumentError => error
    redirect_back_or_to characters_path, alert: error.message
  end

  def destroy
    @character.unarchive!
    redirect_to (params[:return_to] == "character" ? character_path(@character) : characters_path), notice: "#{@character.short_name} is back from the archive."
  end
end
