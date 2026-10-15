# Push yourself (pg. 18): when a task pool roll drops nothing, take a mark to
# drop 1d anyway.
class Campaigns::Pools::PushesController < ApplicationController
  include PoolScoped

  def create
    if @pool.pushable?
      @pool.push!(by: Current.identity)
      back_to_pools notice: "Pushed: take a mark."
    else
      back_to_pools alert: "Only a task pool roll that dropped nothing can be pushed."
    end
  end
end
