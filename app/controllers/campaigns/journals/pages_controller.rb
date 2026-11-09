# The pages of a journal (JournalPage): the player adds, changes and tears out
# their own; a GM adds pages of their own, which they may lock so the player
# can only read them. Saving comes back to the journal, or to the sheet whose
# Journal card it was written from.
class Campaigns::Journals::PagesController < ApplicationController
  include CampaignScoped

  before_action :set_journal
  before_action :set_page, only: %i[ edit update destroy ]

  def create
    raise ActiveRecord::RecordNotFound unless @journal.writable_by?(Current.membership)

    @page = @journal.write!(Current.membership, title: page_params[:title], body: page_params[:body], locked: page_params[:locked] == "1")
    redirect_to back_to, notice: "#{@page.heading} added."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to back_to, alert: error.record.errors.full_messages.to_sentence
  end

  def edit
  end

  def update
    changes = page_params.slice(:title, :body)
    changes[:locked] = page_params[:locked] == "1" if @page.by_gm? && gm?
    @page.update!(changes)
    redirect_to back_to, notice: "#{@page.heading} saved."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @page.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @page.destroy!
    redirect_to back_to(anchor: nil), notice: "#{@page.heading} torn out."
  end

  private
    def page_params
      params.expect(journal_page: %i[ title body locked ])
    end

    # The journal, or the sheet whose Journal card the page was written from.
    def back_to(anchor: (@page&.persisted? ? "page-#{@page.id}" : nil))
      if (character = Current.campaign.characters.find_by(id: params[:character_id]))
        character_path(character, anchor: "journal")
      else
        campaign_journal_path(Current.campaign, @journal.membership, anchor: anchor)
      end
    end

    def set_journal
      @journal = Current.campaign.memberships.find(params[:journal_id]).journal
      raise ActiveRecord::RecordNotFound unless @journal.readable_by?(Current.membership)
    end

    def set_page
      @page = @journal.pages_for(Current.membership).find(params[:id])
      raise ActiveRecord::RecordNotFound unless @journal.editable_by?(@page, Current.membership)
    end
end
