# The GM table: the scene and suspense on top, the party, pools as cards and
# the crucible, with the table's log and chat beside them. GM only; players
# play from their sheets and the campaign page.
class Campaigns::TablesController < ApplicationController
  include CampaignScoped, CampaignTable

  before_action :require_gm

  def show
    return redirect_to campaign_path(Current.campaign) if Current.campaign.archived?

    load_table
  end
end
