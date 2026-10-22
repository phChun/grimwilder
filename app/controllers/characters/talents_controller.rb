# Choosing talents for a character from the catalog: the one per level, or with
# `eldritch=1`, a warlock's Eldritch Talents (Character::EldritchTalents).
class Characters::TalentsController < ApplicationController
  include CharacterScoped

  before_action :set_eldritch

  def new
    # The character's own path first, then the rest in book order. Eldritch
    # Talents are path talents, so background ones are left out.
    @groups = Talent.groups.partition { |group| group.name == @character.path }.flatten
    @groups = @groups.select(&:path?) if @eldritch
  end

  def create
    talent = @eldritch ? @character.add_eldritch_talent!(params.expect(:talent)) : @character.add_talent!(params.expect(:talent))
    redirect_to character_path(@character, anchor: "talents"), notice: "#{@character.name} took #{talent.name}#{" as an Eldritch Talent" if @eldritch}."
  rescue ActiveRecord::RecordInvalid
    redirect_to new_character_talent_path(@character, eldritch: (1 if @eldritch)), alert: @character.errors.full_messages.to_sentence
  end

  def destroy
    @eldritch ? @character.remove_eldritch_talent!(params[:id]) : @character.remove_talent!(params[:id])
    redirect_to character_path(@character, anchor: "talents")
  end

  private
    def set_eldritch
      @eldritch = params[:eldritch].present?
      head :not_found if @eldritch && !@character.eldritch_talents?
    end
end
