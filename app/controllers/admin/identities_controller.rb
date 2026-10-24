# Every account, and making one by hand while sign-ups are closed. A new
# account signs in like any other, with an emailed code.
class Admin::IdentitiesController < Admin::BaseController
  def index
    load_identities
    @identity = Identity.new
  end

  def create
    attributes = params.expect(identity: %i[ email_address name ])
    @identity = Identity.find_or_initialize_by(email_address: attributes[:email_address])
    @identity.name = attributes[:name] if @identity.new_record?

    if @identity.persisted?
      redirect_to admin_identities_path, notice: "#{@identity.email_address} already has an account."
    elsif @identity.save
      redirect_to admin_identities_path, notice: "Account ready for #{@identity.email_address}. They can sign in with an emailed code."
    else
      load_identities
      render :index, status: :unprocessable_entity
    end
  end

  private
    def load_identities
      @identities = Identity.includes(memberships: :campaign).order(created_at: :desc)
      @passkey_counts = Passkey.group(:identity_id).count
    end
end
