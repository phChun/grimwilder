# Using up an expendable arcana (a potion, a scroll, a trophy), or putting it
# back if that was a mistake.
class Characters::ArcanaUsesController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_archived, :set_arcanum

  def create
    @arcanum.use_up!
    note_to_table "#{@character.name} uses up #{@arcanum.name}"
    back_to_arcanum
  end

  def destroy
    @arcanum.restore!
    back_to_arcanum
  end

  private
    def set_arcanum
      @arcanum = @character.arcana.where(expendable: true).find(params[:arcanum_id])
    end

    def back_to_arcanum
      refresh_sheet_and_table
      redirect_to character_path(@character, anchor: "arcanum-#{@arcanum.id}")
    end
end
