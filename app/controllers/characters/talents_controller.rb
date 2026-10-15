# Choosing talents for a character from the catalog.
class Characters::TalentsController < ApplicationController
  include CharacterScoped

  def new
    # The character's own path first, then the rest in book order.
    @groups = Talent.groups.partition { |group| group.name == @character.path }.flatten
  end

  def create
    talent = @character.add_talent!(params.expect(:talent))
    redirect_to character_path(@character, anchor: "talents"), notice: "#{@character.name} took #{talent.name}."
  rescue ActiveRecord::RecordInvalid
    redirect_to new_character_talent_path(@character), alert: @character.errors.full_messages.to_sentence
  end

  def destroy
    @character.remove_talent!(params[:id])
    redirect_to character_path(@character, anchor: "talents")
  end
end
