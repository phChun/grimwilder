# The talent picker's Save (characters/talents/new): the character's whole
# list of chosen talents at once, or with `eldritch=1` their Eldritch Talents,
# so adding, removing and swapping are one step.
class Characters::TalentListsController < ApplicationController
  include CharacterScoped

  def update
    eldritch = params[:eldritch].present?
    return head :not_found if eldritch && !@character.eldritch_talents?

    keys = Array(params[:talents])
    added, removed = eldritch ? @character.set_eldritch_talents!(keys) : @character.set_talents!(keys)
    redirect_to character_path(@character, anchor: "talents"), notice: saved_notice(added, removed)
  rescue ActiveRecord::RecordInvalid
    redirect_to new_character_talent_path(@character, eldritch: (1 if eldritch)), alert: @character.errors.full_messages.to_sentence
  end

  private
    def saved_notice(added, removed)
      said = [ ("took #{added.map(&:name).to_sentence}" if added.any?), ("dropped #{removed.map(&:name).to_sentence}" if removed.any?) ].compact
      return "No change to #{@character.name}'s talents." if said.empty?

      picks = added.select { _1.choices.reject(&:optional?).any? }
      "#{@character.name} #{said.to_sentence}.#{" Make #{picks.map(&:name).to_sentence}'s picks on #{picks.one? ? "its card" : "their cards"}." if picks.any?}"
    end
end
