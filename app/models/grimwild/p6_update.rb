# Moves saved characters from Preview 5.2 to Preview 6 (docs/design/p6-update,
# Phase 2): According to Plan became Mastermind, and Expertise's skill list
# was rewritten. Run once by a migration; running it again changes nothing.
# Roll history keeps the old names: each roll stored its talents' names.
module Grimwild::P6Update
  TALENT_KEYS = { "according-to-plan" => "mastermind" }.freeze
  OLD_NAMES = { "according-to-plan" => "According to Plan" }.freeze

  # P5.2 skill => P6 skill; nil where P6 has nothing like it.
  SKILLS = {
    "persuade" => "charm", "evade" => "parkour", "traverse" => "parkour",
    "forgery & disguise" => "deception", "lying" => "deception", "sabotage" => "dismantle",
    "duel" => nil, "track" => nil
  }.freeze

  # Choices that pick from Expertise's skills (Natural Moxie's are the same list).
  SKILL_CHOICES = { "expertise" => "skills", "natural-moxie" => "skills" }.freeze

  module_function

  def run!
    Character.find_each { update!(_1) }
  end

  def update!(character)
    notes = []
    changes = {}

    TALENT_KEYS.each do |old, new|
      renamed = rename_talent(character, old, new)
      next if renamed.empty?

      changes.merge!(renamed)
      notes << "#{OLD_NAMES[old]} is now #{Talent.find(new).name} (Preview 6)."
    end

    choices = changes["talent_choices"] || character.talent_choices
    SKILL_CHOICES.each do |talent_key, choice_key|
      picks = choices.dig(talent_key, choice_key) or next
      updated, said = map_skills(picks)
      next if said.empty?

      choices = choices.deep_dup.tap { _1[talent_key][choice_key] = updated }
      notes << "#{Talent.find(talent_key).name} skills updated for Preview 6: #{said.join("; ")}."
    end
    changes["talent_choices"] = choices unless choices == character.talent_choices

    return if changes.empty?

    Character.transaction do
      character.update_columns(changes)
      TALENT_KEYS.each do |old, new|
        Pool.where(character_id: character.id).where("use_key LIKE ?", "#{old}/%").find_each do |pool|
          pool.update_columns(use_key: pool.use_key.sub(old, new))
        end
      end
      Roll.note!(campaign: character.campaign, by: character.identity, character: character, text: notes.join(" ")) if character.campaign
    end
  end

  # The columns that change when a talent's key does: its place in the
  # talent lists, and everything kept by key or by use id ("key/use").
  def rename_talent(character, old, new)
    changes = {}
    %w[talent_keys eldritch_talent_keys].each do |column|
      keys = character.public_send(column)
      changes[column] = keys.map { _1 == old ? new : _1 } if keys.include?(old)
    end
    %w[talent_choices talent_skins talent_state].each do |column|
      hash = character.public_send(column)
      changes[column] = hash.transform_keys { _1 == old ? new : _1 } if hash.key?(old)
    end
    uses = character.talent_uses
    if uses.keys.any? { _1.start_with?("#{old}/") }
      changes["talent_uses"] = uses.transform_keys { _1.sub(%r{\A#{Regexp.escape(old)}/}, "#{new}/") }
    end
    changes
  end

  # ["lying", "duel", "stealth"] => [["deception", "stealth"], ["lying → deception", "duel dropped (pick a replacement)"]]
  def map_skills(picks)
    said = []
    updated = picks.filter_map do |pick|
      next pick unless SKILLS.key?(pick)

      if (now = SKILLS[pick])
        said << "#{pick} → #{now}"
        now
      else
        said << "#{pick} dropped (pick a replacement)"
        nil
      end
    end
    [ updated.uniq, said ]
  end
end
