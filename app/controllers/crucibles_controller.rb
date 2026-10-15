# Public: no account needed to roll on a crucible.
class CruciblesController < ApplicationController
  def index
    @groups = Crucible.grouped
  end

  def show
    @crucible = Crucible.find(params[:id])
  end
end
