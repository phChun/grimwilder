# Writing one page of your own journal (Journal::Page), by its key
# ("session-4", "after-4", "before"). Saving it blank clears the page.
class Campaigns::Journals::PagesController < ApplicationController
  include CampaignScoped

  before_action :set_page

  def edit
  end

  def update
    @journal.write!(@page, params.expect(journal_entry: [ :body ])[:body])
    redirect_to campaign_journal_path(Current.campaign, Current.membership, anchor: "page-#{@page.key}"), notice: "#{@page.title} saved."
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    @body = params.dig(:journal_entry, :body)
    render :edit, status: :unprocessable_entity
  end

  private
    def set_page
      @journal = Current.campaign.memberships.find(params[:journal_id]).journal
      raise ActiveRecord::RecordNotFound unless @journal.writable_by?(Current.membership)

      @page = @journal.page(params[:id]) or raise ActiveRecord::RecordNotFound
    end
end
