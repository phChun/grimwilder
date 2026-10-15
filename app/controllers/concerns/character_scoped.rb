# Loads the character in the URL for its owner; anyone else gets a 404.
module CharacterScoped
  extend ActiveSupport::Concern

  included do
    require_authentication
    before_action :set_character
  end

  private
    def set_character
      @character = Current.identity.characters.find(params[:character_id])
    end
end
