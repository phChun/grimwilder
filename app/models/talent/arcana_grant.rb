# Arcana a talent grants (config/talents.yml `arcana:`): Archivist's 2 minor
# and 1 major, Everything Arcana's 2 major (+1 at levels 2, 4 and 6),
# Trophies' major expendable, Magnum Opus's mythic in the making. The sheet's
# Arcana section reminds the player of them (Character::Arcana#arcana_grants);
# an arcana counts toward a grant when it came from that talent, at that tier.
#
# `optional: true` when the talent's text marks it so (Infusion's Everything Arcana).
class Talent::ArcanaGrant < Data.define(:talent_key, :tier, :count, :growth, :expendable, :opus, :optional)
  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, tier: attributes.fetch(:tier), count: attributes.fetch(:count),
      growth: (attributes[:growth] || {}).transform_keys(&:to_i), expendable: attributes[:expendable] == true,
      opus: attributes[:opus] == true, optional: attributes[:optional] == true)
  end

  def count_at(level)
    count + growth.sum { |at, more| at <= level ? more : 0 }
  end

  def counts?(arcanum)
    arcanum.source == talent_key && arcanum.tier == tier
  end

  # "2 minor arcana", "1 major expendable arcana".
  def to_s(level = 1)
    [ count_at(level), tier, ("expendable" if expendable), "arcana" ].compact.join(" ")
  end
end
