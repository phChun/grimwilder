# Makes an account for someone on the interest list, on the plan the admin
# picks. They sign in with an emailed code, as with an account made by hand.
class Admin::Interests::AccountsController < Admin::BaseController
  def create
    interest = Interest.find(params[:interest_id])
    identity = Identity.find_or_initialize_by(email_address: interest.email_address)

    if identity.persisted?
      redirect_to admin_interests_path, notice: "#{identity.email_address} already has an account."
    else
      identity.update!(plan: params.expect(identity: [ :plan ])[:plan])
      redirect_to admin_interests_path, notice: "Account ready for #{identity.email_address}. Let them know they can sign in with an emailed code."
    end
  end
end
