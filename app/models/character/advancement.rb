# XP and levels (pg. 32): take 1 XP after each session; you advance when you
# fill boxes equal to the next level (level 4 → 5 takes 5 XP). Max level 7.
module Character::Advancement
  extend ActiveSupport::Concern

  included do
    validates :level, numericality: { only_integer: true, in: 1..Grimwild::MAX_LEVEL }
    validates :xp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  def xp_to_next_level
    level + 1
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
