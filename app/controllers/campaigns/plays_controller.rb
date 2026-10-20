# Where "Back to the table" goes: the GM to the GM table, a player to the sheet
# of the character they play here (or the campaign page, if they haven't seated one).
class Campaigns::PlaysController < ApplicationController
  include CampaignScoped

  def show
    character = Current.membership.seated_character unless gm?
    redirect_to character ? character_path(character) : table_path_for_viewer
  end
end
