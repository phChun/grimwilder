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

  # Conditions are { "name", "lasts" }: lasts "scene" for short-term ones that
  # clear after a scene (pg. 29), nil for ordinary ones.
  CONDITION_LASTS = %w[ scene ].freeze

  def conditions=(value)
    super(Array(value).filter_map do |condition|
      condition = condition.is_a?(Hash) ? condition.stringify_keys : { "name" => condition }
      name = condition["name"].to_s.squish.first(80)
      { "name" => name, "lasts" => condition["lasts"].presence_in(CONDITION_LASTS) } if name.present?
    end)
  end

  # A significant rest (pg. 30) clears all marks and harm. Doesn't save.
  def rest
    assign_attributes(Grimwild::STATS.to_h { [ "marked_#{_1}", false ] }.merge(bloodied: false, rattled: false, desperate: false))
  end

  def rest!
    rest
    save!
  end

  def add_condition!(name, lasts: nil)
    update!(conditions: conditions + [ { "name" => name, "lasts" => lasts } ])
  end

  def remove_condition!(index)
    clear_conditions!([ index.to_i ])
  end

  def clear_conditions!(indexes)
    update!(conditions: conditions.reject.with_index { |_, i| indexes.include?(i) })
  end

  # [index, condition] for each "clears after scene" condition.
  def scene_conditions
    conditions.each_with_index.filter_map { |condition, index| [ index, condition ] if condition["lasts"] == "scene" }
  end
end
