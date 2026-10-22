# Montages: whoever calls one picks the seated characters taking part, then
# each player rolls their own (RollCall).
class Campaigns::MontagesController < ApplicationController
  include CampaignScoped

  before_action :set_characters

  def new
  end

  def create
    RollCall.montage!(campaign: Current.campaign, by: Current.identity, scene: params[:scene], characters: participants)
    if params[:then] == "end_scene" && (scene = Current.campaign.current_scene)
      redirect_to new_campaign_scene_ending_path(Current.campaign, scene)
    else
      back_to_table(anchor: "rolls")
    end
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_characters
      @characters = Current.campaign.characters.played.includes(:identity).ordered
    end

    # participants[<character id>][in] is "1" for everyone taking part.
    def participants
      chosen = params.fetch(:participants, {}).permit(@characters.to_h { [ _1.id.to_s, %i[ in ] ] }).to_h
      @characters.select { chosen.dig(_1.id.to_s, :in) == "1" }
    end
end
