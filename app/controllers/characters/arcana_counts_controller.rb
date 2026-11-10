# Counting a counted arcana up or down from the sheet: one more (by=1) or
# one fewer (by=-1).
class Characters::ArcanaCountsController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_archived, :set_arcanum

  def update
    @arcanum.count_by!(params[:by].to_i.clamp(-1, 1))
    refresh_sheet_and_table
    redirect_to character_path(@character, anchor: "arcanum-#{@arcanum.id}")
  end

  private
    def set_arcanum
      @arcanum = @character.arcana.where(counted: true).find(params[:arcanum_id])
    end
end
