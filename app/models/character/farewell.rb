# A character's story ending: they fall or retire (`status`), with when it
# happened and the player's line on how it ended (`farewell`). They stay on
# the campaign page and the Characters page, under the party, and can return
# to play. Only the owner ends their story, and not while the GM holds them
# up for grabs.
module Character::Farewell
  extend ActiveSupport::Concern

  FAREWELL_LIMIT = 200
  ENDINGS = %w[ fallen retired ].freeze

  included do
    normalizes :farewell, with: ->(value) { value.to_s.squish.first(FAREWELL_LIMIT).presence }
    before_save :note_status_change, if: :will_save_change_to_status?

    scope :gone, -> { where(status: ENDINGS) }
  end

  def gone?
    !active?
  end

  # status: "fallen" or "retired". Says so in the table's log.
  def end_story!(status, by:, farewell: nil)
    raise ArgumentError, "Pick fallen or retired." unless ENDINGS.include?(status.to_s)
    raise ArgumentError, "#{name} is up for grabs; a player picks them first." if up_for_grabs?

    update!(status: status, farewell: farewell)
    announce_status!(by, fallen? ? "#{name} has fallen." : "#{name} retires.", self.farewell)
  end

  def return_to_play!(by:)
    raise ArgumentError, "#{name} is still playing." if active?

    update!(status: "active")
    announce_status!(by, "#{name} returns to play.")
  end

  private
    def note_status_change
      self.status_changed_at = Time.current
      self.farewell = nil if active?
    end

    def announce_status!(by, text, farewell = nil)
      return unless campaign

      Roll.note!(campaign: campaign, by: by, character: self, text: [ text, (%(“#{farewell}”) if farewell.present?) ].compact.join(" "))
      campaign.broadcast_table_refresh
    end
end
