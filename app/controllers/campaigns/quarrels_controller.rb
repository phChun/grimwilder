# Quarrels between seated characters. The whole table agrees to one out loud,
# so any member can record it, but only a character's own player can spend
# that character's spark.
class Campaigns::QuarrelsController < ApplicationController
  include CampaignScoped

  before_action :set_characters

  def new
  end

  def create
    Roll.quarrel!(campaign: Current.campaign, by: Current.identity, stakes: params[:stakes], sides: sides)
    redirect_to campaign_path(Current.campaign, anchor: "roll-log")
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_characters
      @characters = Current.campaign.characters.includes(:identity).ordered
    end

    # participants[<character id>][role] is "quarrel", "assist-<character id>" or blank;
    # participants[<character id>][spark] is spark that side spends.
    def sides
      chosen = participants.select { |_, choice| choice[:role].present? }
      leads = chosen.select { |_, choice| choice[:role] == "quarrel" }

      sides = leads.to_h do |id, choice|
        character = @characters.find { _1.id.to_s == id }
        spark = choice[:spark].to_i
        raise ArgumentError, "Only #{character.name}'s player can spend their spark." if spark.positive? && !character.owned_by?(Current.identity)
        [ id, { character: character, spend_spark: spark, helpers: [] } ]
      end

      (chosen.to_a - leads.to_a).each do |id, choice|
        helper = @characters.find { _1.id.to_s == id }
        side = sides[choice[:role].delete_prefix("assist-")]
        raise ArgumentError, "#{helper.name} can only assist someone who's quarreling." unless side
        side[:helpers] << helper
      end

      sides.values
    end

    def participants
      params.fetch(:participants, {}).permit(@characters.to_h { [ _1.id.to_s, %i[ role spark ] ] }).to_h
        .transform_values(&:with_indifferent_access)
    end
end
