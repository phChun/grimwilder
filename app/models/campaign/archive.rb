# A campaign the GM has archived: read-only. Everyone can still read its
# page, history, log and sheets, but nothing new is played there (no
# sessions, rolls, chat, pools or joining), and it no longer counts toward
# anyone's plan (Identity::Plans). The GM can unarchive it, unless that would
# put someone at the table past their plan's limit.
module Campaign::Archive
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
  end

  def archived?
    archived_at.present?
  end

  def archive!(by:)
    raise ArgumentError, "End the session before archiving #{name}." if current_session
    raise ArgumentError, "#{name} is already archived." if archived?

    transaction do
      roll_calls.open.each { _1.cancel!(by: by) }
      post_marker!("#{name} is archived", by: by)
      update!(archived_at: Time.current)
    end
  end

  def unarchive!(by:)
    raise ArgumentError, "#{name} isn't archived." unless archived?
    memberships.includes(:identity).each do |member|
      unless member.identity.room_for?(member.role, except: id)
        plan = member.identity.current_plan
        doing = member.gm? ? "runs" : "plays in"
        raise ArgumentError, "#{member.identity.display_name} #{doing} as many active campaigns as the #{plan.name} plan allows, so #{name} can't come back from the archive."
      end
    end

    transaction do
      update!(archived_at: nil)
      post_marker!("#{name} is back from the archive", by: by)
    end
  end

  # Rolls, messages and roll calls check this on create, so an archived campaign's log stays as it was.
  def refuse_new_play(record)
    record.errors.add(:base, "#{name} is archived. The GM can unarchive it to play.") if archived?
  end
end
