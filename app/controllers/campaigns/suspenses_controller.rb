# The GM's suspense (pg. 96): a +/- counter everyone at the table sees but
# only the GM changes. Starting a session adds 1; everything else is by hand,
# and none of it goes in the log.
class Campaigns::SuspensesController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def update
    step = params[:by].to_i.clamp(-1, 1)
    Current.campaign.update!(suspense: [ Current.campaign.suspense + step, 0 ].max)
    redirect_to campaign_path(Current.campaign)
  end
end
