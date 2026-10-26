# Picks a talent asks for (Character::TalentChoices): Expertise's skills,
# Sorcery's paths and techniques. The owner and the campaign's GM can, like
# re-skins. The form opens in the sheet's modal (shared/_frame_modal).
class Characters::TalentChoicesController < ApplicationController
  require_authentication

  before_action :set_character, :set_talent

  def edit
  end

  def update
    @character.choose_for_talent!(@talent.key, picks)
    @character.broadcast_refresh_later
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-#{@talent.key}")
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      head :forbidden unless @character.tended_by?(Current.identity)
    end

    def set_talent
      @talent = @character.talent_entry(params[:talent_id])
      raise ActiveRecord::RecordNotFound, "#{@talent.name} has nothing to pick" if @talent.choices.empty?
    end

    # { "skills" => [...] }: each choice's list, a hidden blank keeping an emptied
    # one. A spell theorem's school comes in its own list, box for box, and
    # joins its name: "wild fire (evocation)".
    def picks
      keys = @talent.choices.to_h { [ _1.key, [] ] }
      picks = params.fetch(:picks, {}).permit(keys).to_h
      schools = params.fetch(:schools, {}).permit(keys).to_h

      @talent.choices.select(&:school?).each_with_object(picks) do |choice, joined|
        next unless joined[choice.key]
        joined[choice.key] = joined[choice.key].each_with_index.map { |name, index| Talent::Choice.join_school(name, schools.dig(choice.key, index)) }
      end
    end
end
