# A character's arcana (Arcanum; pg. 40–43): the owner and the campaign's GM
# add, change and remove them. The form opens in the sheet's modal
# (shared/_frame_modal); `tier` and `source` preset it from a talent's
# reminder ("Archivist: 1 of 2 minor arcana").
class Characters::ArcanaController < ApplicationController
  include TendedCharacter

  before_action :set_arcanum, only: %i[ edit update destroy ]

  def new
    @arcanum = @character.arcana.build(tier: params[:tier].presence_in(Arcanum::TIERS) || "minor", source: params[:source].presence_in(talent_keys),
      expendable: params[:expendable].present?)
  end

  def create
    @arcanum = @character.arcana.build(arcanum_params)
    if @arcanum.save
      note_to_table "#{@character.name} gains #{@arcanum.name} (#{@arcanum.tier_label.downcase})"
      back_to_arcanum
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @arcanum.update(arcanum_params)
      back_to_arcanum
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @arcanum.destroy!
    refresh_sheet_and_table
    redirect_to character_path(@character, anchor: "arcana"), notice: "#{@arcanum.name} removed."
  end

  private
    def set_arcanum
      @arcanum = @character.arcana.find(params[:id])
    end

    def arcanum_params
      params.expect(arcanum: [ :name, :tier, :function, :description, :limitations, :expendable, :power_pool, :source, touchstones: [] ]).tap do |permitted|
        permitted[:source] = permitted[:source].presence_in(talent_keys) if permitted.key?(:source)
      end
    end

    # The talents that can grant this character arcana.
    def talent_keys
      @character.arcana_grants.map { _1.first.talent_key }.uniq
    end

    def back_to_arcanum
      refresh_sheet_and_table
      redirect_to character_path(@character, anchor: "arcanum-#{@arcanum.id}")
    end
end
