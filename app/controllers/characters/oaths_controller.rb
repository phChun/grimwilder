# Oathbreaker (P6 pg. 69, Character::Oath), from the Paladin's core talent
# card: the owner breaks the oath, or marks the one redemption.
class Characters::OathsController < ApplicationController
  include CharacterScoped

  before_action :refuse_when_campaign_archived

  def create
    @character.break_oath!(by: Current.identity)
    redirect_to character_path(@character, anchor: "talents"), notice: "#{@character.short_name} is an Oathbreaker: Talented replaces Oathsworn."
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talents"), alert: error.message
  end

  def destroy
    @character.redeem_oath!(by: Current.identity)
    redirect_to character_path(@character, anchor: "talents"), notice: "#{@character.short_name} is redeemed: Oathsworn returns."
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talents"), alert: error.message
  end
end
