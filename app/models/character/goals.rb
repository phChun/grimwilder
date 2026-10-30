# Expanded downtime (optional rule, pg. 142; Campaign::DowntimeActions). Plan
# ahead gives a thread for details from that preparation, outside the thread
# cap, until time passes again. Pursue a goal rolls a task pool the character
# keeps (a Pool with goal set), made the first time; at 0d the goal is reached.
module Character::Goals
  extend ActiveSupport::Concern

  GOAL_SIZES = [ 2, 4, 6, 8 ].freeze

  def goal_pools
    talent_pools.where(goal: true).order(:created_at)
  end

  def plan_ahead(note)
    note = note.to_s.squish.first(120).presence or raise ArgumentError, "Say what #{short_name} prepares to plan ahead."
    self.prep_note = note
    self.prep_thread = 1
  end

  def forget_plan
    self.prep_note = nil
    self.prep_thread = 0
  end

  def spend_plan_thread!(by:)
    raise ArgumentError, "#{short_name} has no thread from planning ahead." unless prep_thread.positive?

    update!(prep_thread: 0)
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} spends the thread from planning ahead: #{prep_note}.") if campaign
  end

  # goal_id: one of this character's goal pools, or "new" with a name and size.
  def pursue_goal!(goal_id:, name:, size:, by:, random: Random)
    raise ArgumentError, "#{short_name} isn't at a table." unless campaign

    pool = if goal_id.present? && goal_id.to_s != "new"
      goal_pools.find(goal_id)
    else
      name = name.to_s.squish.first(80).presence or raise ArgumentError, "Name #{short_name}'s goal."
      size = size.to_i.presence_in(GOAL_SIZES) || 4
      talent_pools.create!(campaign: campaign, goal: true, kind: "task", name: "#{short_name}: #{name}", starting_size: size, size: size)
    end
    raise ArgumentError, "#{pool.name} is already reached." if pool.depleted?

    pool.roll!(by: by, random: random)
  end
end
