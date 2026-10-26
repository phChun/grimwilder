# Picks a talent asks for (Talent::Choice): Expertise's skills, Weapon
# Mastery's style, Sorcery's paths and techniques. Any of the character's
# talents can have them: the core, chosen ones and Eldritch Talents.
#
# talent_choices: { "expertise" => { "skills" => ["stealth", "lying", "duel"] } }.
# A spell theorem keeps its school with it: "wild fire (evocation)".
#
# Some choices pick from the character's other picks (Bailiwick's word from
# Hidden Magic's words, Mastered Theorem from the theorems); without those
# talents, the player types their own.
#
# Picking fewer than the slots is fine (the card asks for the rest). Like the
# talent limit, picks are checked only when they change, and only the choices
# that changed: a sheet over the cap after its level drops says so, but still
# saves spark, harm and other talents' picks.
module Character::TalentChoices
  extend ActiveSupport::Concern

  included do
    validate :talent_choices_fit, if: -> { will_save_change_to_talent_choices? }
  end

  def choice_slots(choice)
    choice.slots_at(level)
  end

  def picks_for(choice)
    Array(talent_choices.dig(choice.talent_key, choice.key))
  end

  # What the choice picks from: the book's list, or the character's own picks
  # for the talents it draws on.
  def choice_options(choice)
    return choice.options unless choice.from_picks?

    choice_sources_held(choice).flat_map { picks_for(_1) }.uniq
  end

  def choice_open?(choice)
    choice.open? || (choice.from_picks? && choice_sources_held(choice).empty?)
  end

  # { choice => [picks] } for each of the talent's choices.
  def choices_for(talent)
    talent.choices.index_with { picks_for(_1) }
  end

  def choices_left(choice)
    [ choice_slots(choice) - picks_for(choice).size, 0 ].max
  end

  # More picks than the level allows: the card asks for some to go.
  def extra_choices(choice)
    [ picks_for(choice).size - choice_slots(choice), 0 ].max
  end

  # [[talent, choice, how many left]] across every talent the character has.
  def choices_to_make
    [ *talent_entries, *eldritch_talent_entries ].flat_map do |talent|
      talent.choices.filter_map { |choice| [ talent, choice, choices_left(choice) ] if choices_left(choice).positive? }
    end
  end

  # picks: { "skills" => ["stealth", "lying"] }, for one or more of the
  # talent's choices. Closed lists take the option's own spelling; blanks go.
  def choose_for_talent!(key, picks)
    talent = talent_entry(key)
    chosen = talent_choices.fetch(talent.key, {}).dup

    picks.to_h.each do |choice_key, values|
      choice = talent.choice(choice_key) or raise ActiveRecord::RecordNotFound, "#{talent.name} has no choice #{choice_key.inspect}"
      values = Array(values).map { clean_pick(choice, _1) }.compact_blank
      values.empty? ? chosen.delete(choice.key) : chosen[choice.key] = values
    end

    update!(talent_choices: chosen.empty? ? talent_choices.except(talent.key) : talent_choices.merge(talent.key => chosen))
  end

  private
    def choice_sources_held(choice)
      held = [ *talent_entries, *eldritch_talent_entries ].map(&:key)
      choice.picks_sources.select { held.include?(_1.talent_key) }
    end

    # Squished and capped, in the option's own spelling when it's one of them;
    # a theorem's school lowercased after its name.
    def clean_pick(choice, value)
      name, school = choice.school? ? Talent::Choice.split_school(value.to_s.squish) : [ value, nil ]
      name = name.to_s.squish.first(Character::WORD_LIMIT)
      name = choice_options(choice).find { _1.casecmp?(name) } || name
      Talent::Choice.join_school(name, school)
    end

    def talent_choices_fit
      before = talent_choices_was.to_h
      talents = [ *talent_entries, *eldritch_talent_entries ].index_by(&:key)

      talent_choices.each do |talent_key, chosen|
        next if chosen == before[talent_key]

        unless (talent = talents[talent_key])
          errors.add(:talent_choices, "include picks for a talent #{name} doesn't have (#{talent_key})")
          next
        end

        chosen.each do |choice_key, values|
          next if values == before.dig(talent_key, choice_key)

          if (choice = talent.choice(choice_key))
            check_picks(talent, choice, Array(values))
          else
            errors.add(:talent_choices, "include an unknown choice for #{talent.name} (#{choice_key})")
          end
        end
      end
    end

    def check_picks(talent, choice, values)
      slots = choice_slots(choice)
      noun = choice.noun

      unless choice_open?(choice)
        options = choice_options(choice)
        values.reject { options.include?(_1) }.each do |value|
          errors.add(:base, "#{value.inspect} isn't one of #{talent.name}'s #{noun.pluralize}")
        end
      end
      if choice.school?
        values.filter_map { Talent::Choice.split_school(_1).last }.reject { Grimwild.magic_schools.key?(_1) }.each do |school|
          errors.add(:base, "#{school.inspect} isn't a school of magic")
        end
      end
      names = choice.school? ? values.map { Talent::Choice.split_school(_1).first } : values
      if names.map(&:downcase).uniq.size < names.size
        errors.add(:base, "#{talent.name} has the same #{noun} twice")
      end
      if values.size > slots
        errors.add(:base, "At level #{level}, #{talent.name} has room for #{slots} #{noun.pluralize(slots)}")
      end
      if choice.min_each.positive? && values.size >= slots
        choice.option_groups.each do |group, options|
          if values.count { options.include?(_1) } < choice.min_each
            errors.add(:base, "#{talent.name} needs at least #{choice.min_each} from #{group}")
          end
        end
      end
    end
end
