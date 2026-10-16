# What a session or scene boundary does to a character who's there for it
# (pg. 31): a session resets thread (2, plus any from talents), gives spark
# (not before session 1), and resets talent uses and pools; a scene ending
# resets the per-scene ones.
module Character::Sessions
  extend ActiveSupport::Concern

  SESSION_THREAD = 2

  included do
    has_and_belongs_to_many :play_sessions, join_table: :play_session_characters
  end

  def session_thread
    SESSION_THREAD + talent_thread
  end

  def start_session!(first: false)
    self.thread = session_thread
    settle_spark(take: !first)
    reset_talent_uses(per: :session)
    save!
    refresh_talent_pools!(per: :session)
  end

  def end_scene!
    reset_talent_uses(per: :scene)
    save!
    refresh_talent_pools!(per: :scene)
  end
end
