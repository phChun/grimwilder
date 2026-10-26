# Magnum Opus (pg. 55): before each session, roll touchstones for the opus
# (create), then lock one of them in for good (update, `touchstone`).
class Characters::MagnumOpusesController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_done, :set_arcanum

  rescue_from ArgumentError do |error|
    redirect_to character_path(@character, anchor: "arcanum-#{@arcanum.id}"), alert: error.message
  end

  def create
    @arcanum.roll_opus_touchstones!
    back_to_opus
  end

  def update
    word = params.expect(:touchstone)
    @arcanum.lock_opus_touchstone!(word)
    note_to_table "#{@character.name} locks #{word} into #{@arcanum.name}"
    back_to_opus
  end

  private
    def set_arcanum
      @arcanum = @character.arcana.where(source: Arcanum::OPUS).find(params[:arcanum_id])
    end

    def back_to_opus
      refresh_sheet_and_table
      redirect_to character_path(@character, anchor: "arcanum-#{@arcanum.id}")
    end
end
