# Seating a character in one of the owner's campaigns, moving it, or taking
# it away from the table (Character::Seating), from the character list or the
# sheet's Adjust menu.
class Characters::SeatsController < ApplicationController
  require_authentication

  def update
    character = Current.identity.characters.find(params[:character_id])
    campaign = Current.identity.campaigns.find(params[:campaign_id]) if params[:campaign_id].present?

    character.seat!(campaign, by: Current.identity)
    redirect_back_or_to character, notice: campaign ? "#{character.name} is seated in #{campaign.name}." : "#{character.name} isn't in a campaign now."
  rescue ArgumentError => error
    redirect_back_or_to character, alert: error.message
  end
end
