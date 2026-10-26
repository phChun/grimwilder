# A talent from the book (config/talents.yml): each path's core talent and its
# seven path talents, plus background and heritage talents. Any path can take
# any talent (pg. 52) except those marked "[Prohibited: Path]".
#
# Read-only reference data, like Crucible, so it isn't in the database.
class Talent < Data.define(:key, :name, :summary, :text, :note, :page, :group, :core, :uses, :rolls, :choices)
  def self.all
    catalog[:talents]
  end

  def self.groups
    catalog[:groups]
  end

  def self.find(key)
    all.find { |talent| talent.key == key.to_s } || raise(ActiveRecord::RecordNotFound, "No talent #{key.inspect}")
  end

  def self.find_by_key(key)
    all.find { |talent| talent.key == key.to_s }
  end

  def self.core_for(path)
    all.find { |talent| talent.core? && talent.group.name == path }
  end

  # Talents a character can choose: never a core talent, never one prohibited for their path.
  def self.choosable_for(path)
    all.reject { |talent| talent.core? || talent.prohibited_for?(path) }
  end

  def self.catalog
    return load_catalog unless Rails.env.production?

    @catalog ||= load_catalog
  end

  def self.load_catalog
    groups, talents = [], []

    YAML.load_file(Rails.root.join("config/talents.yml")).each do |attributes|
      group = Group.new(**attributes.slice("key", "name", "kind", "page", "aka", "tagline").symbolize_keys)
      groups << group

      if core = attributes["core"]
        talents << build(core, group: group, core: true)
      end

      attributes["talents"].each do |talent|
        talents << build(talent, group: group, core: false)
      end
    end

    { groups: groups, talents: talents }
  end

  def self.build(attributes, group:, core:)
    key = keyify(attributes["name"])
    new(key: key, name: attributes["name"], summary: attributes["summary"], text: attributes["text"], note: (attributes["note"] unless core), page: attributes["page"],
      group: group, core: core, uses: Array(attributes["uses"]).map { Talent::Use.from(key, _1) },
      rolls: Array(attributes["rolls"]).each_with_index.map { Talent::Roll.from(key, _2, _1) },
      choices: Array(attributes["choices"]).map { Talent::Choice.from(key, _1) })
  end

  def self.keyify(name)
    name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").delete_prefix("-").delete_suffix("-")
  end

  class Group < Data.define(:key, :name, :kind, :page, :aka, :tagline)
    def path?
      kind == "path"
    end

    # The core talent first, then the rest A to Z.
    def talents
      Talent.all.select { |talent| talent.group == self }.sort_by { [ _1.core? ? 0 : 1, _1.name.downcase ] }
    end
  end

  def core?
    core
  end

  def choice(key)
    choices.find { _1.key == key.to_s }
  end

  # What a talent does at the table, for the badges on its card. A talent
  # with none of these is always on.
  KINDS = %w[ Spell Roll Pool Uses Push Always ].freeze

  def kinds
    found = [
      ("Spell" if spellcasting?),
      ("Roll" if rolls.any?),
      ("Pool" if uses.any?(&:pool?)),
      ("Uses" if uses.any?(&:counter?)),
      ("Push" if pushes?)
    ].compact
    found.presence || [ "Always" ]
  end

  def spellcasting?
    text.match?(/spellcasting/i)
  end

  # "You can push yourself to…": use it, then mark a stat (pg. 21).
  def pushes?
    text.match?(/push yourself/i)
  end

  # A core talent's "GROWTH: At levels 3 and 6, …" line, without the label.
  def growth
    text[/GROWTH:\s*([^\n]+)/, 1]&.strip
  end

  # "One time only…" features, which thematic path talents can't use (pg. 53).
  def one_time_only?
    text.match?(/one time only/i)
  end

  def prohibited_paths
    text.scan(/\[Prohibited: ([^\]]+)\]/).flatten.flat_map { _1.split(/,\s*/) }
  end

  def prohibited_for?(path)
    prohibited_paths.include?(path)
  end

  # Paragraphs, without the "[Prohibited: …]" marker (shown separately) or,
  # for a core talent, its GROWTH line (shown on its own).
  def paragraphs
    text.sub(/\s*\[Prohibited: [^\]]+\]/, "").then { core? ? _1.sub(/GROWTH:[^\n]+/, "") : _1 }.split(/\n{2,}/).map(&:strip).compact_blank
  end

  def to_param
    key
  end
end
