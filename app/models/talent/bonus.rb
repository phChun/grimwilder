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
# - `counts_as: reckless`: the roller's 5s count as 6s and 4s as 1s (Into the
#   Fray, Audacity…; Grimwild::Dice.count_as).
# - `cast`: the roll casts a spell, so two or more 1s, thorns included, are a
#   magical twist (Sorcery, Maelstrom, Wonder Magnet).
# - `assist`: it applies when this character assists someone else's roll: its
#   dice join the assist (Guardian, Shepherd), and `counts_as: teamwork`
#   counts the assist's 5s as 6s. `spark: perfect_both`: on a perfect, the
#   roller and the assist both take spark (Shepherd).
# - `thorns_from`: one of the talent's track uses whose thorns it adds, and
#   that nothing removes (Awakened Mind's instability on a psionic spell).
# - `during: frenzy`: only while in a frenzy (Character::TalentState).
class Talent::Bonus < Data.define(:talent_key, :key, :label, :dice, :on, :stats, :choice, :use, :per_mark, :harm, :ignore, :auto, :counts_as, :cast, :assist, :spark, :thorns_from, :during)
  ROLLS = %w[ action defense ].freeze
  GROUP_ROLLS = %w[ story montage ].freeze
  IGNORES = %w[ damage situational ].freeze

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes.fetch(:label), dice: attributes.fetch(:dice, 1),
      on: Array(attributes[:only] || ROLLS), stats: Array(attributes[:stats]), choice: attributes[:choice], use: attributes[:use],
      per_mark: attributes[:per_mark] || false, harm: attributes[:harm] || false, ignore: attributes[:ignore], auto: attributes[:auto] || false,
      counts_as: attributes[:counts_as], cast: attributes[:cast] || false, assist: attributes[:assist] || false, spark: attributes[:spark],
      thorns_from: attributes[:thorns_from], during: attributes[:during])
  end

  # "expertise/skill", what the roll setup posts.
  def id
    "#{talent_key}/#{key}"
  end

  def use_id
    "#{talent_key}/#{use}" if use
  end

  def thorns_from_id
    "#{talent_key}/#{thorns_from}" if thorns_from
  end

  def auto?
    auto
  end

  # Whether it can apply to an action or defense roll with this stat. Both
  # modes share one setup, so a defense-only bonus is offered on both and
  # counted only on a defense.
  def for_stat?(stat)
    !assist && (on & ROLLS).any? && (stats.empty? || stats.include?(stat.to_s))
  end

  def applies_to?(mode, stat)
    on.include?(mode.to_s) && (stats.empty? || stats.include?(stat.to_s))
  end

  def defense_only?
    on == [ "defense" ]
  end
end
