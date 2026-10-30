# "Copy for an AI" on the GM table: the campaign and the party as Markdown
# (Campaign::Brief), in a box the GM can read, edit and copy. GM only.
class Campaigns::BriefsController < ApplicationController
  include CampaignScoped

  before_action :require_gm

  def show
    @markdown = Campaign::Brief.new(Current.campaign).to_markdown
  end
end
