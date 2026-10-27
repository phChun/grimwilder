# Something a talent asks the player to pick (config/talents.yml `choices:`):
# Expertise's 3 skills, Weapon Mastery's fighting style, Sorcery's sources and
# techniques. Picks are stored on the character (Character::TalentChoices).
#
# - `pick`: how many at level 1; `growth` adds more at those levels ({ 3 => 1, 6 => 1 }).
# - `from`: the book's options, or `groups` of them by name ("Above board"),
#   with `min_each` picks from every group once the slots are full.
# - `open: true` when the book says "such as": the options are suggestions,
#   and the player can type their own.
# - `same_as: "expertise.skills"` takes another talent's list (Natural Moxie).
# - `touchstone: true` when the picks are the talent's magic touchstones (pg. 36).
# - `from_list: magic_schools` takes a list from config/grimwild.yml (a hash
#   of lists is groups: the Bard's song composition).
# - `from_picks: [spellcraft.theorems, …]` picks from what the character
#   picked for those talents (Bailiwick, Mastered Theorem); a character with
#   none of those talents types their own (Character::TalentChoices#choice_open?).
# - `crucible: patron` rolls for ideas on that crucible (`table: Nature` for
#   one of its tables), filling the boxes from the roll.
# - `noun` names one pick when the label's singular reads badly, and
#   `plural` names several when Rails would get a phrase wrong ("words of power").
# - `optional: true` when the talent marks that part optional (Infusion's
#   Everything Arcana): the sheet offers it without asking for it.
# - `school: true` for spell theorems: each pick carries a school of magic,
#   stored as "wild fire (evocation)".
# - `hints`: the book's one line on what an option means ("charm: Persuade
#   with personality."), shown in the picker.
class Talent::Choice < Data.define(:talent_key, :key, :label, :noun, :pick, :from, :groups, :min_each, :open, :same_as, :touchstone, :growth,
  :from_list, :from_picks, :crucible, :table, :school, :plural, :optional, :hints)
  SCHOOLED = /\A(?<name>.+?) \((?<school>[a-z]+)\)\z/i

  # "wild fire (evocation)" => ["wild fire", "evocation"]; a name alone has no school.
  def self.split_school(value)
    match = SCHOOLED.match(value.to_s)
    match ? [ match[:name], match[:school] ] : [ value.to_s, nil ]
  end

  def self.join_school(name, school)
    name, school = name.to_s.squish, school.to_s.strip.downcase
    name.present? && school.present? ? "#{name} (#{school})" : name
  end

  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes.fetch(:label), noun: attributes[:noun] || attributes[:label].downcase.singularize,
      pick: attributes.fetch(:pick), from: Array(attributes[:from]), groups: attributes[:groups] || {}, min_each: attributes[:min_each].to_i,
      open: attributes[:open] == true, same_as: attributes[:same_as], touchstone: attributes[:touchstone] == true,
      growth: (attributes[:growth] || {}).transform_keys(&:to_i), from_list: attributes[:from_list], from_picks: Array(attributes[:from_picks]),
      crucible: attributes[:crucible], table: attributes[:table], school: attributes[:school] == true, plural: attributes[:plural], optional: attributes[:optional] == true,
      hints: attributes[:hints] || {})
  end

  # Unique across talents: "expertise/skills".
  def id
    "#{talent_key}/#{key}"
  end

  def open?
    open
  end

  def touchstone?
    touchstone
  end

  def school?
    school
  end

  def optional?
    optional
  end

  # Picks with a school: theorems, or a pick from them (Mastered Theorem).
  def schooled?
    school? || picks_sources.any?(&:school?)
  end

  # Picks come from the character's other picks, so the options depend on them.
  def from_picks?
    from_picks.any?
  end

  # The choices whose picks this one takes: [Talent::Choice].
  def picks_sources
    from_picks.filter_map do |source|
      talent_key, choice_key = source.split(".")
      Talent.find_by_key(talent_key)&.choice(choice_key)
    end
  end

  def roll_crucible
    Crucible.find(crucible) if crucible
  end

  # What the card calls the picks.
  def heading
    touchstone? ? "Touchstones" : label
  end

  # "3 skills", at level 1 or the one given.
  def to_s(level = 1)
    slots = slots_at(level)
    "#{slots} #{nouns(slots)}"
  end

  # "skill", "skills"; "word of power", "words of power".
  def nouns(count = 2)
    count == 1 ? noun : plural || noun.pluralize
  end

  def slots_at(level)
    pick + growth.sum { |at, more| at <= level ? more : 0 }
  end

  # The choice whose list this one uses: another talent's, with `same_as`.
  def source
    return self unless same_as

    talent_key, choice_key = same_as.split(".")
    Talent.find_by_key(talent_key)&.choice(choice_key)
  end

  # { "Above board" => [...], "Below table" => [...] }, or { nil => [...] } for a plain list.
  # A `from_list` that's a hash of lists is groups too (the Bard's song
  # composition); a hash of descriptions gives its keys (magic schools).
  def option_groups
    list = source
    return list.groups if list.groups.present?

    value = list.from_list ? Grimwild.public_send(list.from_list) : list.from
    if value.is_a?(Hash) && value.values.all?(Array) then value
    else { nil => value.is_a?(Hash) ? value.keys : value }
    end
  end

  def options
    option_groups.values.flatten
  end

  # What an option means, from the list's own hints (Natural Moxie uses Expertise's).
  def hint_for(option)
    source&.hints&.dig(option)
  end

  def grouped?
    option_groups.keys.any?
  end

  def group_of(value)
    option_groups.find { |_, values| values.include?(value) }&.first
  end
end
