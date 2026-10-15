class ProfilesController < ApplicationController
  require_authentication

  def show
    @identity = Current.identity
  end

  def update
    @identity = Current.identity

    @identity.assign_attributes(params.expect(identity: [ :name ]))

    if @identity.save(context: :profile)
      redirect_to session.delete(:return_to_after_authenticating) || campaigns_path, notice: "Saved."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
