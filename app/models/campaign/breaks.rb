# Rest and downtime (pg. 31). A rest is a significant stretch of time: it
# clears all marks and harm. Downtime goes further: PCs fully heal, including
# relevant conditions, and reset per-session talents, and every campaign pool
# is rolled. Both apply to the characters at the current session, or to
# everyone seated between sessions.
module Campaign::Breaks
  extend ActiveSupport::Concern

  def resting_characters
    (current_session ? current_session.characters : characters.played).active.ordered.to_a
  end

  # Faction and other long-term pools, rolled in downtime.
  def downtime_pools
    pools.shared.where(kind: "campaign").ordered.select(&:rollable?)
  end

  def rest!(by:)
    transaction do
      resting = resting_characters.each { _1.rest!(by: by) }
      post_marker!("Rest", by: by, text: ("Marks and harm cleared for #{resting.map(&:name).to_sentence}." if resting.any?))
    end
  end

  # clear: "character_id:index" for each condition to clear (the form ticks
  # them all; untick permanent ones).
  def downtime!(by:, clear: [], random: Random)
    picks = Array(clear).map { _1.to_s.split(":", 2) }.group_by(&:first).transform_values { |pairs| pairs.map { _2.to_i } }

    transaction do
      resting = resting_characters
      post_marker!("Downtime", by: by, text: ("Everyone heals: #{resting.map(&:name).to_sentence}." if resting.any?))

      resting.each do |character|
        cleared = picks.fetch(character.id.to_s, [])
        character.rest(by: by)
        character.conditions = character.conditions.reject.with_index { |_, index| cleared.include?(index) }
        character.reset_talent_uses(per: :session)
        character.save!
        character.refresh_talent_pools!(per: :session)
      end
      downtime_pools.each { _1.roll!(by: by, random: random) }
    end
  end
end
