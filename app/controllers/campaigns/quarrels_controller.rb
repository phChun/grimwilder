# Quarrels between seated characters. The whole table agrees to one out loud,
# so any member can call it; then each player rolls their own side or assist
# (RollCall).
class Campaigns::QuarrelsController < ApplicationController
  include CampaignScoped

  before_action :set_characters

  def new
  end

  def create
    RollCall.quarrel!(campaign: Current.campaign, by: Current.identity, stakes: params[:stakes], sides: sides)
    back_to_table(anchor: "rolls")
  rescue ArgumentError => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_characters
      @characters = Current.campaign.characters.played.includes(:identity).ordered
    end

    # participants[<character id>][role] is "quarrel", "assist-<character id>" or blank.
    def sides
      chosen = participants.select { |_, choice| choice[:role].present? }
      leads = chosen.select { |_, choice| choice[:role] == "quarrel" }

      sides = leads.to_h do |id, _|
        [ id, { character: @characters.find { _1.id.to_s == id }, helpers: [] } ]
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
      params.fetch(:participants, {}).permit(@characters.to_h { [ _1.id.to_s, %i[ role ] ] }).to_h
        .transform_values(&:with_indifferent_access)
    end
end
