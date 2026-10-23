# A character's story ending: they fall or retire (`status`), with when it
# happened and the player's line on how it ended (`farewell`). They stay on
# the campaign page and the Characters page, under the party, and can return
# to play. Only the owner ends their story, and not while the GM holds them
# up for grabs. However the status changes (these methods or a status
# update), the table's log says so in the same transaction.
module Character::Farewell
  extend ActiveSupport::Concern

  FAREWELL_LIMIT = 200
  ENDINGS = %w[ fallen retired ].freeze

  included do
    normalizes :farewell, with: ->(value) { value.to_s.squish.first(FAREWELL_LIMIT).presence }
    before_save :note_status_change, if: :will_save_change_to_status?
    validate :not_up_for_grabs, if: -> { will_save_change_to_status? && persisted? }
    after_update :announce_status, if: :saved_change_to_status?

    scope :gone, -> { where(status: ENDINGS) }
  end

  def gone?
    !active?
  end

  # Still playing, at a table that's still playing (or at none): rolls, pushes
  # and talent rolls show only then. A done campaign's sheets are for reading.
  def in_play?
    active? && !campaign&.done?
  end

  # status: "fallen" or "retired".
  def end_story!(status, by:, farewell: nil)
    raise ArgumentError, "Pick fallen or retired." unless ENDINGS.include?(status.to_s)
    raise ArgumentError, "#{name} is up for grabs; a player picks them first." if up_for_grabs?

    self.changed_by = by
    update!(status: status, farewell: farewell)
  end

  def return_to_play!(by:)
    raise ArgumentError, "#{name} is still playing." if active?
    raise ArgumentError, "#{name} is up for grabs; a player picks them first." if up_for_grabs?

    self.changed_by = by
    update!(status: "active")
  end

  private
    def note_status_change
      self.status_changed_at = Time.current
      self.farewell = nil if active?
    end

    def not_up_for_grabs
      errors.add(:status, "can't change while #{name} is up for grabs; a player picks them first") if up_for_grabs?
    end

    def announce_status
      return unless campaign

      text = if active? then "#{name} returns to play." elsif fallen? then "#{name} has fallen." else "#{name} retires." end
      Roll.note!(campaign: campaign, by: changed_by || identity, character: self,
        text: [ text, (%(“#{farewell}”) if farewell.present?) ].compact.join(" "))
      campaign.broadcast_table_refresh
    end
end
