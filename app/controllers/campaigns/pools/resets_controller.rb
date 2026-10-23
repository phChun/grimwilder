class Campaigns::Pools::ResetsController < ApplicationController
  include PoolScoped

  before_action :require_gm

  def create
    @pool.reset!
    tell_the_player if @pool.character
    back_to_pools
  end

  private
    # A talent pool lives on its player's sheet: log the reset and refresh the sheet.
    def tell_the_player
      Roll.note!(campaign: Current.campaign, by: Current.identity, character: @pool.character,
        text: "#{Current.identity.display_name} resets #{@pool.name} to #{@pool.size}d")
      @pool.character.broadcast_refresh_later
    end
end
