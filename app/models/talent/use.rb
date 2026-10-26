# Something a talent gives each session or scene (config/talents.yml `uses:`):
#
# - a count of uses: 3 inspiration per session (`count`), shown as tick boxes;
# - a talent pool: a 3d Grenades resource pool per session (`pool`, `pool_kind`),
#   with `drop_first: true` when the talent's text drops 1d before rolling it
#   (a potent spell from a rite, a wild talent on Wild Shape), and with
#   `bonus_dice: true` when a power pool is rolled as extra dice for another
#   roll (Luck, Quarry, Competence), never as an action in place of a stat;
# - extra thread per session (`thread`), from Bardic Lore, Reader and the like.
#
# A count can be `named_by` one of the talent's choices: each box is one of
# the character's picks (Hidden Magic burns its words of power by name), or
# have fixed `names` (Primordial Bonds' four elements, a vassal's mark and
# harm), with `verb` for what ticking one does ("charge", "mark"; "burn"
# unless it says). A `tally` counts up with no most (Mischief Maker's
# overloads). A `track` lists the thorns each box adds once ticked (Awakened
# Mind's instability: [ 0, 1, 2 ], with growth adding more 0t boxes first).
#
# `per`: when it resets: each `session` or `scene`, at a `rest` (rest and
# downtime), or `never` (charges kept until spent; a one-time potion).
# A pool can also `refill` at 0d: `always` (Pact's Patience) or that many
# times before it resets (the Vassal's once).
#
# `growth` adds to the count or pool at those levels: { 2 => 1, 4 => 1, 6 => 1 }.
class Talent::Use < Data.define(:talent_key, :key, :label, :per, :count, :pool, :pool_kind, :thread, :growth, :drop_first, :bonus_dice, :named_by,
  :names, :verb, :tally, :track, :refill)
  PERS = %w[ session scene rest never ].freeze

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    track = attributes[:track]
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes[:label], per: attributes[:per] || "session",
      count: attributes[:count] || attributes[:names]&.size || track&.size, pool: attributes[:pool], pool_kind: attributes[:pool_kind], thread: attributes[:thread],
      growth: (attributes[:growth] || {}).transform_keys(&:to_i), drop_first: attributes[:drop_first] == true,
      bonus_dice: attributes[:bonus_dice] == true, named_by: attributes[:named_by], names: attributes[:names], verb: attributes[:verb] || "burn",
      tally: attributes[:tally] == true, track: track, refill: attributes[:refill])
  end

  # Unique across talents: "inspiration/inspiration", "spellcraft/spells".
  def id
    "#{talent_key}/#{key}"
  end

  def counter?
    !count.nil? || tally
  end

  def tally?
    tally
  end

  def track?
    !track.nil?
  end

  def pool?
    !pool.nil?
  end

  def thread?
    !thread.nil?
  end

  def named?
    !named_by.nil? || !names.nil?
  end

  # The thorns each box adds, in order, at this level: growth's 0t boxes first.
  def track_at(level)
    Array.new(count_at(level) - track.size, 0) + track
  end

  # Pools that refill at 0d: how many times before the use resets (nil: no
  # refill; Float::INFINITY for always).
  def refills
    refill == "always" ? Float::INFINITY : refill
  end

  def per_scene?
    per == "scene"
  end

  def count_at(level)
    grown(count, level) unless tally?
  end

  def pool_at(level)
    grown(pool, level)
  end

  def resets
    { "scene" => "resets each scene", "session" => "resets each session", "rest" => "clears with a rest", "never" => "kept until spent" }.fetch(per)
  end

  def resets_with?(period)
    period.to_s == "session" ? per.in?(%w[ session scene ]) : per == period.to_s
  end

  private
    def grown(base, level)
      base.to_i + growth.sum { |at, more| at <= level ? more : 0 }
    end
end
