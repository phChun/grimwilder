# A campaign is on hold when every one of its GMs' memberships is held: their
# plans run fewer campaigns than they have (Identity::Plans#apply_plan!). One
# GM with room keeps it going. On hold sits between active and archived: the
# page, log and sheets read as usual, chat works, sheets can be edited and
# people can still join and seat characters, but nothing is played (sessions,
# scenes, rolls, roll calls, pools), and it doesn't count toward the GM's plan.
module Campaign::Hold
  extend ActiveSupport::Concern

  def on_hold?
    return @on_hold unless @on_hold.nil?
    held = memberships.gm.pluck(:held_at)
    @on_hold = held.any? && held.all?(&:present?)
  end

  def reload(...)
    @on_hold = nil
    super
  end

  # Not archived and not on hold: sessions, rolls and pools can happen.
  def playable?
    !archived? && !on_hold?
  end

  def not_playable_message
    if archived? then "#{name} is archived."
    elsif on_hold? then on_hold_message
    end
  end

  def on_hold_message
    "#{name} is on hold. Its GM can choose to play it from the campaigns list."
  end

  # For model methods that play: raises with why it can't.
  def refuse_play!
    raise ArgumentError, not_playable_message unless playable?
  end

  # When the session that was played last started (or when the campaign was
  # made, if it's never been played): what "most recently played" means for
  # choosing which campaigns stay unheld.
  def last_played_at
    [ play_sessions.maximum(:started_at), created_at ].compact.max
  end
end
