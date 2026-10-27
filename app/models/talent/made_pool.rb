# A pool a talent makes when it's used (config/talents.yml `makes:`): Echo's
# 3d duplicate, Awaken's living feature, Soothsayer's Spirit pool, Animate
# Objects' animated things. Made from the talent's card, as a talent pool
# (Pool with character_id and made_by_talent), and gone when it `lasts` out:
# the end of the scene or session.
#
# `use` ticks one of the talent's uses to make one; `at_once` caps how many
# there can be (three animated objects); `named` asks what it is ("the old
# oak", "the river"); `bonus_dice` rolls it as extra dice after a roll (a
# follow-up) rather than as an action.
class Talent::MadePool < Data.define(:talent_key, :key, :label, :pool, :kind, :use, :at_once, :lasts, :named, :bonus_dice)
  LASTS = %w[ scene session ].freeze

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes.fetch(:label), pool: attributes.fetch(:pool),
      kind: attributes[:kind] || "power", use: attributes[:use], at_once: attributes[:at_once] || 1, lasts: attributes[:lasts] || "session",
      named: attributes[:named] || false, bonus_dice: attributes[:bonus_dice] || false)
  end

  # The pool's use_key: "echo/echo".
  def id
    "#{talent_key}/#{key}"
  end

  def use_id
    "#{talent_key}/#{use}" if use
  end

  # Talent::Use's flags, so Pool#talent_use can return either.
  def drop_first
    false
  end

  def refills
  end
end
