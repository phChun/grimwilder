# Every account, searchable by email or name, 50 a page; making one by hand while sign-ups are closed, and choosing
# each one's plan (Identity::Plans). A new account signs in like any other,
# with an emailed code.
class Admin::IdentitiesController < Admin::BaseController
  def index
    load_identities
    @identity = Identity.new
  end

  def create
    attributes = params.expect(identity: %i[ email_address name plan ])
    @identity = Identity.find_or_initialize_by(email_address: attributes[:email_address])
    @identity.assign_attributes(attributes.slice(:name, :plan)) if @identity.new_record?

    if @identity.persisted?
      redirect_to admin_identities_path, notice: "#{@identity.email_address} already has an account."
    elsif @identity.save
      redirect_to admin_identities_path, notice: "Account ready for #{@identity.email_address}. They can sign in with an emailed code."
    else
      load_identities
      render :index, status: :unprocessable_entity
    end
  end

  # Through Identity#apply_plan!: a smaller plan puts the campaigns past its
  # limit on hold (the GM picks which to play), and a bigger one lifts holds.
  def update
    identity = Identity.find(params[:id])
    plan = params.expect(identity: [ :plan ])[:plan]
    return redirect_to(admin_identities_path, alert: "There's no #{plan} plan.") unless Plan.keys.include?(plan)
    identity.apply_plan!(plan)
    redirect_to admin_identities_path, notice: "#{identity.display_name} is on the #{identity.current_plan.name} plan."
  end

  private
    def load_identities
      @pagy, identities = pagy(:offset, search(Identity.order(created_at: :desc), "email_address", "name"), limit: PER_PAGE)
      @identities = identities.includes(memberships: :campaign).to_a
      @passkey_counts = Passkey.where(identity_id: @identities.map(&:id)).group(:identity_id).count
    end
end
