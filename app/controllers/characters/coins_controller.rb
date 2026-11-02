# Wealth (pg. 176, Character::RulePools#add_coins!): carousing adds 2d to the
# Coins pool, up to 8d. The owner and the campaign's GM.
class Characters::CoinsController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_archived

  def create
    @character.add_coins!(by: Current.identity)
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-rule")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-rule"), alert: error.message
  end
end
