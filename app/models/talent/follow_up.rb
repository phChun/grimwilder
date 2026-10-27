# Something a talent does to a roll after it's made (config/talents.yml
# `follow_ups:`), offered under the roll in the log and on the roll toast
# (Roll::FollowUps):
#
# - `bonus`: roll a talent pool as bonus dice that join the roll (Luck,
#   Soothsayer's Spirit); 1–3s drop from the pool as usual. With `dice` and no
#   pool, that many d6s that never run out (Quarry's quarry die).
# - `reroll`: roll the same dice again, without thorns (Blessed).
# - `raise`: +1 to one die (Inspiration, Warcry; Component Pouch rolls its
#   pool to do it).
# - `assist`: assist after the roll, with 1d of your own (Got Your Back).
# - `critical_effect`: nothing changes on the dice; the log notes that it adds
#   a critical effect (Weapon Mastery's mastery, pg. 11).
# - `omen`: swap any d6 for one of your omens, which then erases (Augury).
#
# `use` ticks one of the talent's uses and `pool` rolls one of its talent
# pools. `who`: `self` (your own rolls), `allies` (others' at your table) or
# `anyone`. `rolls`: which kinds (action and defense unless it says; story
# rolls too for Luck and Quarry). `results`: only after these outcomes.
# `after`: only on a roll that took this talent bonus. `spark`: who takes
# spark when: `six` (a bonus die shows 6: the roller), `grim_die` (a bonus die
# shows 1–3: you), `perfect` (you), or `perfect_both` (you and the roller).
# `six: critical_effect`: a bonus die showing 6 adds a critical effect (the
# quarry die). `needs`: only while the actor has some of that talent state
# (`quarries`: a quarry chosen this session).
class Talent::FollowUp < Data.define(:talent_key, :key, :kind, :label, :use, :pool, :who, :rolls, :results, :after, :spark, :dice, :six, :needs)
  KINDS = %w[ bonus reroll raise assist critical_effect omen ].freeze
  WHO = %w[ self allies anyone ].freeze
  ROLLS = %w[ action defense story ].freeze
  SPARK = %w[ six grim_die perfect perfect_both ].freeze
  NEEDS = %w[ quarries ].freeze

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), kind: attributes.fetch(:kind), label: attributes.fetch(:label),
      use: attributes[:use], pool: attributes[:pool], who: attributes[:who] || "self", rolls: Array(attributes[:rolls] || %w[ action defense ]),
      results: Array(attributes[:results]), after: attributes[:after], spark: attributes[:spark],
      dice: attributes[:dice], six: attributes[:six], needs: attributes[:needs])
  end

  # "lucky/luck", what the follow-up form posts.
  def id
    "#{talent_key}/#{key}"
  end

  def use_id
    "#{talent_key}/#{use}" if use
  end

  def pool_id
    "#{talent_key}/#{pool}" if pool
  end

  # Whether a character can do it to the same roll again: inspiration can be
  # spent twice on one roll, but Luck rolls once.
  def repeatable?
    kind.in?(%w[ raise omen ])
  end

  def for_roller?(own)
    who == "anyone" || (own ? who == "self" : who == "allies")
  end
end
