# Extra dice (or thorns ignored) a talent gives a roll when the situation fits
# (config/talents.yml `bonuses:`): Expertise's +1d with a chosen skill, Aegis's
# +1d defending against physical harm. Offered as a tick in the stat card's
# roll setup, so the log can say where a die came from.
#
# - `only`: the rolls it applies to (`[ defense ]`, `[ story ]`, `[ montage ]`),
#   else action and defense. Story rolls and montages are ticked at the roll call.
# - `stats`: only for these stats (Lightning Reflexes: Agility).
# - `choice`: the talent's choice whose picks it names ("Duel, Stealth").
# - `use`: one of the talent's uses it ticks (Artificial Parts' perks).
# - `per_mark`: +1d for each marked stat instead of `dice` (Frenzy).
# - `harm`: +1d for each thorn harm adds to this stat (Oathsworn).
# - `ignore`: thorns it leaves out: `damage` (marks and harm) or `situational`.
# - `auto`: always applies when it fits, so it's shown rather than ticked.
class Talent::Bonus < Data.define(:talent_key, :key, :label, :dice, :on, :stats, :choice, :use, :per_mark, :harm, :ignore, :auto)
  ROLLS = %w[ action defense ].freeze
  GROUP_ROLLS = %w[ story montage ].freeze
  IGNORES = %w[ damage situational ].freeze

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes.fetch(:label), dice: attributes.fetch(:dice, 1),
      on: Array(attributes[:only] || ROLLS), stats: Array(attributes[:stats]), choice: attributes[:choice], use: attributes[:use],
      per_mark: attributes[:per_mark] || false, harm: attributes[:harm] || false, ignore: attributes[:ignore], auto: attributes[:auto] || false)
  end

  # "expertise/skill", what the roll setup posts.
  def id
    "#{talent_key}/#{key}"
  end

  def use_id
    "#{talent_key}/#{use}" if use
  end

  def auto?
    auto
  end

  # Whether it can apply to an action or defense roll with this stat. Both
  # modes share one setup, so a defense-only bonus is offered on both and
  # counted only on a defense.
  def for_stat?(stat)
    (on & ROLLS).any? && (stats.empty? || stats.include?(stat.to_s))
  end

  def applies_to?(mode, stat)
    on.include?(mode.to_s) && (stats.empty? || stats.include?(stat.to_s))
  end

  def defense_only?
    on == [ "defense" ]
  end
end
