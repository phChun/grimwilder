# A talent from the book (config/talents.yml): each path's core talent and its
# seven path talents, plus background and heritage talents. Any path can take
# any talent (pg. 52) except those marked "[Prohibited: Path]".
#
# Read-only reference data, like Crucible, so it isn't in the database.
class Talent < Data.define(:key, :name, :text, :note, :page, :group, :core)
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
        talents << new(key: keyify(core["name"]), name: core["name"], text: core["text"], note: nil, page: core["page"], group: group, core: true)
      end

      attributes["talents"].each do |talent|
        talents << new(key: keyify(talent["name"]), name: talent["name"], text: talent["text"], note: talent["note"], page: talent["page"], group: group, core: false)
      end
    end

    { groups: groups, talents: talents }
  end

  def self.keyify(name)
    name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").delete_prefix("-").delete_suffix("-")
  end

  class Group < Data.define(:key, :name, :kind, :page, :aka, :tagline)
    def path?
      kind == "path"
    end

    def talents
      Talent.all.select { |talent| talent.group == self }
    end
  end

  def core?
    core
  end

  def prohibited_paths
    text.scan(/\[Prohibited: ([^\]]+)\]/).flatten.flat_map { _1.split(/,\s*/) }
  end

  def prohibited_for?(path)
    prohibited_paths.include?(path)
  end

  # Paragraphs, without the "[Prohibited: …]" marker (shown separately).
  def paragraphs
    text.sub(/\s*\[Prohibited: [^\]]+\]/, "").split(/\n{2,}/)
  end

  def to_param
    key
  end
end
