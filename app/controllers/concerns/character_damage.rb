# Marks, harm and conditions on a sheet: the character's owner or their
# campaign's GM may change them (Character#tended_by?). When the GM does, it
# goes in the table's log ("Gwen marked Bloodied on Tibbs"), and the owner's
# open sheet and the GM table refresh.
module CharacterDamage
  extend ActiveSupport::Concern

  included do
    require_authentication
    before_action :set_character
    before_action :refuse_when_campaign_archived
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:character_id])
      return head :forbidden unless @character.tended_by?(Current.identity)

      @character.changed_by = Current.identity
    end

    # note: false when the change logs itself already (a condition roll).
    def back_to_damage(note: true, **options)
      announce_change(note: note)
      redirect_to helpers.character_path(@character, anchor: "damage"), **options
    end

    def announce_change(note:)
      return unless @character.saved_change_to_harm_changed_at?

      if note && (campaign = @character.campaign) && !@character.owned_by?(Current.identity)
        Roll.note!(campaign: campaign, by: Current.identity, text: "#{@character.harm_change} on #{@character.short_name}")
      end
      @character.broadcast_refresh_later
      @character.campaign&.broadcast_table_refresh
    end
end
