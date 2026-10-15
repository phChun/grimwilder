# The talent catalog: public reference, grouped by path.
class TalentsController < ApplicationController
  def index
    @groups = Talent.groups
  end
end
