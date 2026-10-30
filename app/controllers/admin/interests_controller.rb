# Everyone who asked to try Grimwilder (/interest), newest first, searchable
# by email or note and filtered by how they'd play (?role=: gm, player, both,
# or none for those who didn't say), 50 a page. An admin
# makes an account from a row (Admin::Interests::AccountsController) or
# removes it.
class Admin::InterestsController < Admin::BaseController
  def index
    interests = search(Interest.order(created_at: :desc), "email_address", "note")
    @pagy, interests = pagy(:offset, filter_by_role(interests), limit: PER_PAGE)
    @interests = interests.to_a
    @accounts = Identity.where(email_address: @interests.map(&:email_address)).index_by(&:email_address)
  end

  def destroy
    interest = Interest.find(params[:id])
    interest.destroy!
    redirect_to admin_interests_path, notice: "#{interest.email_address} removed from the list."
  end

  private
    def filter_by_role(scope)
      case params[:role]
      when *Interest::ROLES.keys then scope.where(role: params[:role])
      when "none" then scope.where(role: nil)
      else scope
      end
    end
end
