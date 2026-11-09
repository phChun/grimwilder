# Players' journals (Journal): pages they write as they like. The GM's list
# of them (index), one to read and add to (show, by membership: the player's
# own, or a GM's, who sees their own pages and the player's while it's
# shared; anyone else gets a 404), and the player's switch for letting the GM
# read it (update).
class Campaigns::JournalsController < ApplicationController
  include CampaignScoped

  before_action :set_journal, only: %i[ show update ]

  def index
    return redirect_to(campaign_journal_path(Current.campaign, Current.membership)) unless gm?

    @players = Current.campaign.memberships.player.includes(:identity, :journal_pages).order(:created_at)
  end

  def show
    @pages = @journal.pages_for(Current.membership)
  end

  def update
    return head(:forbidden) unless @journal.membership == Current.membership

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
