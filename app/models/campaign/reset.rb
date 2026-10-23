# Starting a campaign's play over: every session (with its scenes and
# attendance), the whole roll log (rolls, notes, markers) and any roll call
# go. Chat stays, and so does the rest of the game: pools, suspense, and the
# characters with their XP and levels.
module Campaign::Reset
  extend ActiveSupport::Concern

  def reset!(by:)
    transaction do
      roll_calls.open.each { _1.cancel!(by: by) } # gives back any spark already spent into them
      roll_calls.delete_all
      rolls.delete_all # scenes' opening and closing rolls are nulled by the database
      play_sessions.delete_all # scenes and attendance go with them (on_delete: :cascade)
    end
    broadcast_table_refresh
  end
end
