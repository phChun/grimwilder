# A warlock's Eldritch Talents (Pact, pg. 82): path talents gifted by the
# patron, 1 at the start and +1 at levels 3 and 6, changeable given time to
# commune. They're extra: they don't count against the one chosen talent per
# level (Character::Talents), so they live in their own list with their own
# cap. As "thematic path talents" (pg. 53) they can't use "One time only…"
# features, which the sheet points out.
module Character::EldritchTalents
  extend ActiveSupport::Concern

  # The core talent that gifts them.
  PACT = "pact"
  GROWTH_LEVELS = [ 3, 6 ].freeze

  included do
    validate :eldritch_talents_are_choosable, if: -> { will_save_change_to_eldritch_talent_keys? }
    # Like the chosen-talent limit: only when they or the level change.
    validate :eldritch_talents_fit_level, if: -> { will_save_change_to_eldritch_talent_keys? || will_save_change_to_level? || will_save_change_to_path? }
  end

  def eldritch_talents?
    core_talent_entry&.key == PACT
  end

  def eldritch_talent_slots
    eldritch_talents? ? 1 + GROWTH_LEVELS.count { level >= _1 } : 0
  end

  def eldritch_talents
    eldritch_talent_keys.filter_map { Talent.find_by_key(_1) }
  end

  def eldritch_talents_to_choose
    [ eldritch_talent_slots - eldritch_talent_keys.size, 0 ].max
  end

  def extra_eldritch_talents
    [ eldritch_talent_keys.size - eldritch_talent_slots, 0 ].max
  end

  def eldritch_talents_full?
    eldritch_talent_keys.size >= eldritch_talent_slots
  end

  def has_eldritch_talent?(talent)
    eldritch_talent_keys.include?(talent.key)
  end

  # Path talents only (not background ones), never a core, a prohibited one,
  # or one already chosen with a level.
  def eldritch_choosable?(talent)
    eldritch_talents? && talent.group.path? && !talent.core? && !talent.prohibited_for?(path) && !has_talent?(talent)
  end

  def add_eldritch_talent!(key)
    talent = Talent.find(key)
    update!(eldritch_talent_keys: eldritch_talent_keys + [ talent.key ]) unless has_eldritch_talent?(talent)
    talent
  end

  def remove_eldritch_talent!(key)
    update!(eldritch_talent_keys: eldritch_talent_keys - [ key.to_s ], talent_skins: talent_skins.except(key.to_s), talent_choices: talent_choices.except(key.to_s))
  end

  private
    def eldritch_talents_are_choosable
      eldritch_talent_keys.each do |key|
        talent = Talent.find_by_key(key)
        if talent.nil?
          errors.add(:eldritch_talent_keys, "include an unknown talent (#{key})")
        elsif !eldritch_choosable?(talent)
          errors.add(:base, "#{talent.name} can't be an Eldritch Talent for #{name}")
        end
      end
    end

    def eldritch_talents_fit_level
      if extra_eldritch_talents.positive?
        errors.add(:base, "At level #{level}, #{name} has room for #{eldritch_talent_slots} Eldritch #{"Talent".pluralize(eldritch_talent_slots)}; remove one first")
      end
    end
end
