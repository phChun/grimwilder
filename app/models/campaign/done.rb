# A campaign the GM has marked done: a read-only archive. Everyone can still
# read its page, history, log and sheets, but nothing new is played there (no
# sessions, rolls, chat, pools or joining), and it no longer counts toward
# anyone's plan (Identity::Plans). The GM can reopen it, unless that would put
# someone at the table past their plan's limit.
module Campaign::Done
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(done_at: nil) }
    scope :done, -> { where.not(done_at: nil) }
  end

  def done?
    done_at.present?
  end

  def mark_done!(by:)
    raise ArgumentError, "End the session before marking #{name} done." if current_session
    raise ArgumentError, "#{name} is already done." if done?

    transaction do
      roll_calls.open.each { _1.cancel!(by: by) }
      post_marker!("#{name} is done", by: by)
      update!(done_at: Time.current)
    end
  end

  def reopen!(by:)
    raise ArgumentError, "#{name} isn't done." unless done?
    memberships.includes(:identity).each do |member|
      unless member.identity.room_for?(member.role, except: id)
        plan = member.identity.current_plan
        doing = member.gm? ? "runs" : "plays in"
        raise ArgumentError, "#{member.identity.display_name} #{doing} as many active campaigns as the #{plan.name} plan allows, so #{name} can't reopen."
      end
    end

    transaction do
      update!(done_at: nil)
      post_marker!("#{name} reopens", by: by)
    end
  end

  # Rolls, messages and roll calls check this on create, so a done campaign's log stays as it was.
  def refuse_new_play(record)
    record.errors.add(:base, "#{name} is done. The GM can reopen it to play.") if done?
  end
end
