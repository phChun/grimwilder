# Something a talent gives each session or scene (config/talents.yml `uses:`):
#
# - a count of uses: 3 inspiration per session (`count`), shown as tick boxes;
# - a talent pool: a 3d Grenades resource pool per session (`pool`, `pool_kind`);
# - extra thread per session (`thread`), from Bardic Lore, Reader and the like.
#
# `growth` adds to the count or pool at those levels: { 2 => 1, 4 => 1, 6 => 1 }.
class Talent::Use < Data.define(:talent_key, :key, :label, :per, :count, :pool, :pool_kind, :thread, :growth)
  PERS = %w[ session scene ].freeze

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes[:label], per: attributes[:per] || "session",
      count: attributes[:count], pool: attributes[:pool], pool_kind: attributes[:pool_kind], thread: attributes[:thread],
      growth: (attributes[:growth] || {}).transform_keys(&:to_i))
  end

  # Unique across talents: "inspiration/inspiration", "spellcraft/spells".
  def id
    "#{talent_key}/#{key}"
  end

  def counter?
    !count.nil?
  end

  def pool?
    !pool.nil?
  end

  def thread?
    !thread.nil?
  end

  def per_scene?
    per == "scene"
  end

  def count_at(level)
    grown(count, level)
  end

  def pool_at(level)
    grown(pool, level)
  end

  def resets
    per_scene? ? "resets each scene" : "resets each session"
  end

  private
    def grown(base, level)
      base.to_i + growth.sum { |at, more| at <= level ? more : 0 }
    end
end
