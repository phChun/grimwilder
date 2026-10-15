# Marks, harm and conditions (pg. 27–29), and the thorns they add to rolls.
module Character::Damage
  extend ActiveSupport::Concern

  def marked?(stat)
    public_send(:"marked_#{stat}")
  end

  # +1t for a mark on the stat, +1t for bloodied (Brawn, Agility) or rattled
  # (Wits, Presence), and +1t on every roll while desperate.
  def damage_thorns(stat)
    stat = stat.to_s
    thorns = 0
    thorns += 1 if marked?(stat)
    thorns += 1 if bloodied? && Grimwild::PHYSICAL_STATS.include?(stat)
    thorns += 1 if rattled? && Grimwild::MENTAL_STATS.include?(stat)
    thorns += 1 if desperate?
    thorns
  end

  def damage_reasons(stat)
    stat = stat.to_s
    [
      ("marked" if marked?(stat)),
      ("bloodied" if bloodied? && Grimwild::PHYSICAL_STATS.include?(stat)),
      ("rattled" if rattled? && Grimwild::MENTAL_STATS.include?(stat)),
      ("desperate" if desperate?)
    ].compact
  end

  # A mark clears after the next roll with that stat.
  def roll!(stat_name)
    stat_name = stat_name.to_s
    raise ArgumentError, "Unknown stat #{stat_name.inspect}" unless Grimwild::STATS.include?(stat_name)

    roll = { dice: stat(stat_name), thorns: damage_thorns(stat_name), reasons: damage_reasons(stat_name) }
    update!("marked_#{stat_name}" => false) if marked?(stat_name)
    roll
  end

  def add_condition!(name)
    name = name.to_s.squish.first(80)
    update!(conditions: conditions + [ name ]) if name.present?
  end

  def remove_condition!(index)
    update!(conditions: conditions.reject.with_index { |_, i| i == index.to_i })
  end
end
