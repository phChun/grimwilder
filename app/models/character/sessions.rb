# What a session boundary does to a character who's there for it (pg. 31):
# thread resets and they take spark (not before session 1).
module Character::Sessions
  extend ActiveSupport::Concern

  SESSION_THREAD = 2

  included do
    has_and_belongs_to_many :play_sessions, join_table: :play_session_characters
  end

  def session_thread
    SESSION_THREAD
  end

  def start_session!(first: false)
    self.thread = session_thread
    settle_spark(take: !first)
    save!
  end
end
