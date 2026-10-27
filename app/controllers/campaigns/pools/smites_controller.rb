# Oathsworn's smite (pg. 69): after a task pool is rolled, a player spends
# their character's smite to drop 1d from it.
class Campaigns::Pools::SmitesController < ApplicationController
  include PoolScoped

  def create
    character = Current.campaign.characters.where(identity: Current.identity).find(params.expect(:character_id))
    @pool.smite!(character: character, by: Current.identity)
    back_to_pools notice: "#{character.short_name} smites: 1d dropped."
  rescue ArgumentError => error
    back_to_pools alert: error.message
  end
end
