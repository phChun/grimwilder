# Where "Back to the table" goes: the GM to the table, a player to the sheet of
# the character they play here (or the table, if they haven't seated one).
class Campaigns::PlaysController < ApplicationController
  include CampaignScoped

  def show
    character = Current.membership.seated_character unless gm?
    redirect_to character ? character_path(character) : campaign_path(Current.campaign)
  end
end
