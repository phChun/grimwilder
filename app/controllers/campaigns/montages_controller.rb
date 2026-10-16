# Montage rolls for the seated characters taking part in a stretch of story.
class Campaigns::MontagesController < ApplicationController
  include CampaignScoped, SparkSpending

  before_action :set_characters

  def new
  end

  def create
    Roll.montage!(campaign: Current.campaign, by: Current.identity, scene: params[:scene], participants: participants)
    if params[:then] == "end_scene" && (scene = Current.campaign.current_scene)
      redirect_to new_campaign_scene_ending_path(Current.campaign, scene)
    else
      redirect_to campaign_path(Current.campaign, anchor: "roll-log")
    end
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_characters
      @characters = Current.campaign.characters.includes(:identity).ordered
    end

    # participants[<character id>][in] is "1" for everyone taking part;
    # participants[<character id>][spark] is spark they spend.
    def participants
      chosen = params.fetch(:participants, {}).permit(@characters.to_h { [ _1.id.to_s, %i[ in spark ] ] }).to_h

      @characters.filter_map do |character|
        choice = chosen[character.id.to_s]
        { character: character, spend_spark: spark_to_spend(character, choice[:spark]) } if choice&.dig(:in) == "1"
      end
    end
end
