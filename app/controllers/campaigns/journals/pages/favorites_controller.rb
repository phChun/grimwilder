# The player starring a page of their journal (JournalPage#favorite), so it
# comes first in the journal and on the sheet.
class Campaigns::Journals::Pages::FavoritesController < ApplicationController
  include CampaignScoped

  before_action :set_page

  def create
    @page.update!(favorite: true)
    redirect_to back_to
  end

  def destroy
    @page.update!(favorite: false)
    redirect_to back_to
  end

  private
    def set_page
      @journal = Current.campaign.memberships.find(params[:journal_id]).journal
      raise ActiveRecord::RecordNotFound unless @journal.favoritable_by?(Current.membership)

      @page = @journal.pages_for(Current.membership).find(params[:page_id])
    end

    def back_to
      if (character = Current.campaign.characters.find_by(id: params[:character_id]))
        character_path(character, anchor: "journal")
      else
        campaign_journal_path(Current.campaign, @journal.membership, anchor: "page-#{@page.id}")
      end
    end
end
