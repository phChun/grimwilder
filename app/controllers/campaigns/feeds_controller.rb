# Older lines for the table rail, a page at a time as you scroll back
# (feed_controller.js): the TableFeed page before the given time, as only this
# member may see it.
class Campaigns::FeedsController < ApplicationController
  include CampaignScoped

  def show
    before = Time.iso8601(params.expect(:before))
    render partial: "campaigns/feed_page", locals: { feed: TableFeed.new(Current.campaign, Current.membership, before: before) }
  rescue ArgumentError
    head :bad_request
  end
end
