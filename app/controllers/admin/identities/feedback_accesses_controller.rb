# Turns an account's Feedback button on (create) or off (destroy), from the
# accounts list.
class Admin::Identities::FeedbackAccessesController < Admin::BaseController
  before_action :set_identity

  def create
    @identity.update!(feedback_enabled: true)
    redirect_to admin_identities_path(q: params[:q].presence, page: params[:page].presence), notice: "#{@identity.display_name} can send feedback."
  end

  def destroy
    @identity.update!(feedback_enabled: false)
    redirect_to admin_identities_path(q: params[:q].presence, page: params[:page].presence), notice: "#{@identity.display_name} no longer sees the Feedback button."
  end

  private
    def set_identity
      @identity = Identity.find(params[:identity_id])
    end
end
