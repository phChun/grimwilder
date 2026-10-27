# XP and levels (pg. 32): take 1 XP after each session; you advance when you
# fill boxes equal to the next level (level 4 → 5 takes 5 XP). Max level 7.
#
# Level 0 (optional rule, pg. 177): a character can start with no core talent
# and 3 stat points instead of 4 (`level_zero`). 1 XP takes them to level 1,
# where the core talent arrives and they add their last stat point.
module Character::Advancement
  extend ActiveSupport::Concern

  included do
    validates :level, numericality: { only_integer: true, in: 0..Grimwild::MAX_LEVEL }
    validates :level, numericality: { greater_than: 0, message: "can only be 0 for a character who started at level 0" }, unless: :level_zero?
    before_validation(on: :create) { self.level = 0 if level_zero? }
    validates :xp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  # Focused growth (an optional rule) slashes a box for each one filled.
  def xp_to_next_level
    (level + 1) * (campaign&.optional_rule?(:focused_growth) ? 2 : 1)
  end

  # The stats a character starts with: 1 in each plus 4 points, or 3 at level 0.
  def starting_stat_total
    Character::STARTING_STAT_TOTAL - (level.to_i.zero? ? 1 : 0)
  end

  # The point a level 0 character adds on reaching level 1.
  def stat_point_due?
    level_zero? && level.to_i >= 1 && Grimwild::STATS.sum { stat(_1) } < Character::STARTING_STAT_TOTAL + (stat_progressed? ? 1 : 0)
  end

  def add_stat_point!(name, by:)
    raise ArgumentError, "#{short_name} has no stat point to add." unless stat_point_due?
    raise ArgumentError, "That's not a stat." unless Grimwild::STATS.include?(name.to_s)
    raise ArgumentError, "#{name.to_s.capitalize} is already 3." if stat(name) >= 3

    update!(name => stat(name) + 1)
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} reaches level 1: +1 #{name.to_s.capitalize}.") if campaign
  end

  def max_level?
    level >= Grimwild::MAX_LEVEL
  end

  # Returns true when this XP levels the character up.
  def gain_xp!
    return false if max_level?

    if xp + 1 >= xp_to_next_level
      update!(level: level + 1, xp: 0)
      true
    else
      update!(xp: xp + 1)
      false
    end
  end
end
