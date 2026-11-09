# What changes for a character in play (the sheet's Story card): bonds, arcs
# and notes. The owner edits it in the card, a turbo frame (show is the card,
# edit its form); nothing else changes here.
class Characters::StoriesController < ApplicationController
  include CharacterScoped

  FIELDS = [ :notes, arcs: [], bonds: [ :to, :bond, :character_id ] ].freeze

  # The card's contents, for the frame; on its own, the sheet.
  def show
    redirect_to character_path(@character, anchor: "story") unless turbo_frame_request?
  end

  def edit
  end

  def update
    if @character.update(params.require(:character).permit(*FIELDS))
      @character.broadcast_refresh_later
      redirect_to character_story_path(@character)
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
