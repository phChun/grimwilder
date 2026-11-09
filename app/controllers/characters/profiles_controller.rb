# Who a character is (the sheet's Who card): backgrounds and wises, traits,
# desires, features and what they carry. The owner edits it in the card, a
# turbo frame (show is the card, edit its form); nothing else changes here.
class Characters::ProfilesController < ApplicationController
  include CharacterScoped

  FIELDS = [ :not_trait, :not_desire, :weapons, :armor,
    traits: [], desires: [], features: [], weapon_styles: [], backgrounds: [ :name, wises: [] ] ].freeze

  # The card's contents, for the frame; on its own, the sheet.
  def show
    redirect_to character_path(@character, anchor: "who") unless turbo_frame_request?
  end

  def edit
  end

  def update
    if @character.update(params.require(:character).permit(*FIELDS))
      @character.broadcast_refresh_later
      redirect_to character_profile_path(@character)
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
