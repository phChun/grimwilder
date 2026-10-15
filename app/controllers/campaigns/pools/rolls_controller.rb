class Campaigns::Pools::RollsController < ApplicationController
  include PoolScoped

  def create
    if @pool.rollable?
      @pool.roll!(by: Current.identity, drop_first: params[:drop_first] == "1")
      back_to_pools
    else
      back_to_pools alert: "#{@pool.name} is at 0d. Reset it to roll again."
    end
  end
end
