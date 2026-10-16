# Public: no account needed to roll on a crucible. ?embed=1 renders just the
# roller, in the "crucible" Turbo Frame the GM table loads.
class CruciblesController < ApplicationController
  def index
    @groups = Crucible.grouped
  end

  def show
    @crucible = Crucible.find(params[:id])
    render :embed if params[:embed].present?
  end
end
