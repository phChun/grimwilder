# The table's rail: chat messages and log entries in one time-ordered stream.
# They stay separate models (Message, Roll); this only merges what a member may
# see, for the view, and names the streams that keep it live.
#
# It's paged as one stream, newest first: a page is the PAGE lines before
# `before` (or the newest), whichever kinds they are, so scrolling back
# (feed_controller.js, Campaigns::FeedsController) never skips any.
class TableFeed
  PAGE = 50

  attr_reader :campaign, :membership

  def initialize(campaign, membership, before: nil)
    @campaign, @membership, @before = campaign, membership, before
  end

  # Oldest first, the way a chat reads.
  def entries
    window.last(PAGE)
  end

  # Whether there's more before this page.
  def more?
    window.size > PAGE
  end

  # The next page back ends here.
  def oldest_at
    entries.first&.created_at
  end

  def streams
    Roll.streams_for(campaign, membership) + Message.streams_for(campaign, membership)
  end

  private
    # One more than a page of each kind, merged: the newest PAGE of those are
    # this page, and anything past them means there's more.
    def window
      @window ||= (messages + rolls).sort_by { [ _1.created_at, _1.is_a?(Roll) ? 0 : 1, _1.id ] }.last(PAGE + 1)
    end

    def messages
      Message.where(campaign: campaign).visible_to(membership).includes(:identity, :character).then { before(_1) }
        .order(created_at: :desc, id: :desc).limit(PAGE + 1).to_a
    end

    def rolls
      campaign.rolls.visible_to(membership).includes(:identity, :pool).then { before(_1) }.recent.limit(PAGE + 1).to_a
    end

    def before(scope)
      @before ? scope.where(created_at: ...@before) : scope
    end
end
