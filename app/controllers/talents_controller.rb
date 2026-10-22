# The talent catalog: public reference, grouped by path. ?path= opens it on
# one path's talents (the dropdown keeps it current).
class TalentsController < ApplicationController
  def index
    @groups = Talent.groups
    @selected = params[:path]
  end
end
