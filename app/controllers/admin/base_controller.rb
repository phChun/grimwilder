# The admin zone (/admin): only identities with admin set, which is done by
# hand in the console. Everyone else gets a 404, as a non-member does at a
# campaign.
class Admin::BaseController < ApplicationController
  include AdminSearch
  include Pagy::Method

  require_authentication
  before_action :require_admin

  private
    def require_admin
      raise ActiveRecord::RecordNotFound unless Current.identity.admin?
    end
end
