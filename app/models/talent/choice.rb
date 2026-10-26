# Something a talent asks the player to pick (config/talents.yml `choices:`):
# Expertise's 3 skills, Weapon Mastery's fighting style, Sorcery's paths and
# techniques. Picks are stored on the character (Character::TalentChoices).
#
# - `pick`: how many at level 1; `growth` adds more at those levels ({ 3 => 1, 6 => 1 }).
# - `from`: the book's options, or `groups` of them by name ("Above board"),
#   with `min_each` picks from every group once the slots are full.
# - `open: true` when the book says "such as": the options are suggestions,
#   and the player can type their own.
# - `same_as: "expertise.skills"` takes another talent's list (Natural Moxie).
# - `touchstone: true` when the picks are the talent's magic touchstones (pg. 35).
class Talent::Choice < Data.define(:talent_key, :key, :label, :noun, :pick, :from, :groups, :min_each, :open, :same_as, :touchstone, :growth)
  def self.from(talent_key, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, key: attributes.fetch(:key), label: attributes.fetch(:label), noun: attributes[:noun] || attributes[:label].downcase.singularize,
      pick: attributes.fetch(:pick), from: Array(attributes[:from]), groups: attributes[:groups] || {}, min_each: attributes[:min_each].to_i,
      open: attributes[:open] == true, same_as: attributes[:same_as], touchstone: attributes[:touchstone] == true,
      growth: (attributes[:growth] || {}).transform_keys(&:to_i))
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

  # What the card calls the picks.
  def heading
    touchstone? ? "Touchstones" : label
  end

  # "3 skills", at level 1 or the one given.
  def to_s(level = 1)
    slots = slots_at(level)
    "#{slots} #{noun.pluralize(slots)}"
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
  def option_groups
    list = source
    list.groups.presence || { nil => list.from }
  end

  def options
    option_groups.values.flatten
  end

  def grouped?
    option_groups.keys.any?
  end

  def group_of(value)
    option_groups.find { |_, values| values.include?(value) }&.first
  end

  # The option's own spelling for a pick typed or posted in another case.
  def canonical(value)
    options.find { _1.casecmp?(value) }
  end
end
