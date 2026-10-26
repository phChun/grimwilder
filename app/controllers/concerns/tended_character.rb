# Loads the character in the URL for those who tend it: its owner and its
# campaign's GM (Character#tended_by?). Others at the table get a 403;
# anyone who can't see the character, a 404.
module TendedCharacter
  extend ActiveSupport::Concern

  included do
    require_authentication
    before_action :set_character
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      head :forbidden unless @character.tended_by?(Current.identity)
    end

    # The sheet and the table show it at once.
    def refresh_sheet_and_table
      @character.broadcast_refresh_later
      @character.campaign&.broadcast_table_refresh
    end

    def note_to_table(text)
      Roll.note!(campaign: @character.campaign, by: Current.identity, character: @character, text: text) if @character.campaign
    end
end
