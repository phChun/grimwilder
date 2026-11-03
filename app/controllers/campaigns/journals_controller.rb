# Players' journals (Journal): a page per session or stretch between. The
# GM's list of them (index), one to read or write (show, by membership: the
# player's own, or a GM's read of a shared one; anyone else gets a 404), and
# the player's switch for letting the GM read it (update).
class Campaigns::JournalsController < ApplicationController
  include CampaignScoped

  before_action :set_journal, only: %i[ show update ]

  def index
    return redirect_to(campaign_journal_path(Current.campaign, Current.membership)) unless gm?

    @players = Current.campaign.memberships.player.includes(:identity, :journal_entries).order(:created_at)
  end

  def show
    @pages = @journal.pages(written_only: !@journal.writable_by?(Current.membership))
  end

  def update
    return head(:forbidden) unless @journal.writable_by?(Current.membership)

    shared = params.expect(membership: [ :journal_shared ])[:journal_shared] == "1"
    Current.membership.update!(journal_shared: shared)
    redirect_to campaign_journal_path(Current.campaign, Current.membership),
      notice: shared ? "The GM can read your journal." : "Your journal is just for you now."
  end

  private
    def set_journal
      membership = Current.campaign.memberships.find(params[:id])
      @journal = membership.journal
      raise ActiveRecord::RecordNotFound unless @journal.readable_by?(Current.membership)
    end
end
