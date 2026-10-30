# Rest and downtime (pg. 31). A rest is a significant stretch of time: it
# clears all marks and harm. Downtime goes further: PCs fully heal, including
# relevant conditions, and reset per-session talents, every campaign pool
# is rolled, and then the GM picks one and depletes it completely. Both apply to the characters at the current session, or to
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

  # Rest resets (pg. 175): at a rest the group calls a reset, each character
  # takes spark, resets talents and thread and heals 1 harm, and the GM takes
  # 2 suspense.
  # clear: "character_id:index" for each condition that fades (the form ticks
  # none; some conditions fade, the GM picks which).
  def rest_reset!(by:, clear: [])
    raise ArgumentError, "#{name} doesn't use the Rest resets rule." unless optional_rule?(:rest_resets)

    picks = condition_picks(clear)
    transaction do
      resting = resting_characters.each { _1.rest_reset!(by: by, clear: picks.fetch(_1.id.to_s, [])) }
      increment!(:suspense, 2)
      post_marker!("Reset", by: by, text: ("Spark, talents, thread and 1 harm for #{resting.map(&:name).to_sentence}." if resting.any?))
    end
  end

  # Milestone levels (pg. 177): after a major group arc, the party levels up.
  def milestone!(by:)
    raise ArgumentError, "#{name} doesn't use the Milestone levels rule." unless optional_rule?(:milestone_levels)

    transaction do
      levelled = resting_characters.reject(&:max_level?).each { _1.update!(level: _1.level + 1, xp: 0) }
      post_marker!("Milestone", by: by, level_ups: levelled)
      levelled
    end
  end

  # clear: "character_id:index" for each condition to clear (the form ticks
  # them all; untick permanent ones).
  # deplete: the id of the campaign pool the GM picks to come to pass, after
  # the rolls (nothing more happens if the rolls already emptied it).
  def downtime!(by:, clear: [], deplete: nil, random: Random)
    picks = condition_picks(clear)

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
        character.refresh_talent_pools!(per: :rest)
      end
      downtime_pools.each { _1.roll!(by: by, random: random) }
      if deplete.present? && (pool = pools.shared.where(kind: "campaign").find_by(id: deplete)) && pool.rollable?
        pool.deplete!(by: by)
      end
    end
  end

  private
    # "character_id:index" strings => { "character_id" => [index, …] }
    def condition_picks(clear)
      Array(clear).map { _1.to_s.split(":", 2) }.group_by(&:first).transform_values { |pairs| pairs.map { _2.to_i } }
    end
end
