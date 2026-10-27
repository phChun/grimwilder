# What a session or scene boundary does to a character who's there for it
# (pg. 32): a session resets thread (2, plus any from talents), gives spark
# (not before session 1), resets talent uses and pools, and rolls Augury's
# omens (Character::TalentState); a scene ending resets the per-scene ones
# and ends a frenzy.
module Character::Sessions
  extend ActiveSupport::Concern

  SESSION_THREAD = 2

  included do
    has_and_belongs_to_many :play_sessions, join_table: :play_session_characters
  end

  def session_thread
    SESSION_THREAD + talent_thread
  end

  # Under the Rest resets rule (Campaign::OptionalRules) a session leaves
  # spark, thread and talents alone: the GM's Reset at a rest does it instead.
  def start_session!(first: false)
    resets = !campaign&.optional_rule?(:rest_resets)
    if resets
      self.thread = session_thread
      settle_spark(take: !first)
      reset_talent_uses(per: :session)
    end
    reset_talent_state
    save!
    reset_opus_rolls
    refresh_talent_pools!(per: :session) if resets || first
  end

  # Rest resets (pg. 175): take spark, reset every talent and all thread, and
  # heal 1 harm (the worst first). Saves.
  def rest_reset!(by:)
    self.changed_by = by
    settle_spark(take: true)
    self.thread = session_thread
    %i[ session scene rest ].each { reset_talent_uses(per: _1) }
    worst = %w[ desperate bloodied rattled ].find { public_send(_1) }
    public_send(:"#{worst}=", false) if worst
    save!
    %i[ session rest ].each { refresh_talent_pools!(per: _1) }
  end

  def end_scene!
    reset_talent_uses(per: :scene)
    end_frenzy
    save!
    refresh_talent_pools!(per: :scene)
  end
end
