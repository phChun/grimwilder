class Campaigns::Pools::ResetsController < ApplicationController
  include PoolScoped

  before_action :require_gm

  def create
    @pool.reset!
    back_to_pools
  end
end
