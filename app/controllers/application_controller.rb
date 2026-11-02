class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, with: :not_saved
  rescue_from ActionController::ParameterMissing, with: :not_saved

  private
    # An archived campaign (Campaign::Archive) is read-only, and that includes play on
    # its characters' sheets: harm, conditions, talent uses, pushes, talent
    # rolls. Character controllers aren't CampaignScoped, so they add this
    # after loading @character.
    def refuse_when_campaign_archived
      if (campaign = @character&.campaign)&.archived?
        redirect_back_or_to helpers.character_path(@character), status: :see_other, alert: "#{campaign.name} is archived. The GM can unarchive it to play."
      end
    end

    # A save nothing else caught, or a form sent with something missing: back
    # where they were, with a toast saying why (shared/_toasts), instead of an
    # error page.
    def not_saved(error)
      raise error if request.get? || request.head?

      errors = error.respond_to?(:record) ? error.record&.errors&.full_messages.to_a : [ "Fill in #{error.param.to_s.humanize(capitalize: false)} and try again." ]
      respond_to do |format|
        format.html { redirect_back_or_to root_path, status: :see_other, alert: [ "That didn't save.", errors.to_sentence.presence ].compact.join(" ") }
        format.any { head :unprocessable_entity }
      end
    end
end
