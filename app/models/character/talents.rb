# Talents from the catalog (config/talents.yml). The core talent comes from the
# path; the rest are chosen: one at creation and one per new level (pg. 32, 47),
# so a character at level N has at most N chosen talents, from any path (pg. 53).
# The Adventurer's Talented adds more (Talent#extra_talent_slots), and a level 0
# character (optional rule, pg. 177) has its one talent but no core yet.
# Swapping one means removing it first.
module Character::Talents
  extend ActiveSupport::Concern

  included do
    validate :talents_are_choosable
    # Only when talents or level change, so a sheet that's already over (from
    # before the limit) can still take spark, harm and rolls.
    validate :talents_fit_level, if: -> { will_save_change_to_talent_keys? || will_save_change_to_level? }
  end

  # The path's core talent, or with legacy_core its older version (pg. 179);
  # an oathbroken Paladin's is Talented (Character::Oath); none at level 0.
  def core_talent_entry
    return if level.to_i.zero?
    return Talent.find(Character::Oath::TALENTED) if oathbroken?

    Talent.core_for(path, legacy: legacy_core?)
  end

  def chosen_talents
    talent_keys.filter_map { |key| Talent.find_by_key(key) }
  end

  # One per level (one at level 0 too), plus the core's extras and one kept
  # from a redeemed oath, less one given up for a stat (Character::StatProgression).
  def expected_talent_count
    [ level, 1 ].max + core_talent_entry&.extra_talent_slots(level).to_i + oath_kept_talents - (stat_progressed? ? 1 : 0)
  end

  def talents_to_choose
    [ expected_talent_count - talent_keys.size, 0 ].max
  end

  # More than the level allows: the sheet asks for some to go.
  def extra_talents
    [ talent_keys.size - expected_talent_count, 0 ].max
  end

  def talents_full?
    talent_keys.size >= expected_talent_count
  end

  def has_talent?(talent)
    talent_keys.include?(talent.key)
  end

  def add_talent!(key)
    talent = Talent.find(key)
    update!(talent_keys: talent_keys + [ talent.key ]) unless has_talent?(talent)
    talent
  end

  def remove_talent!(key)
    update!(talent_keys: talent_keys - [ key.to_s ], talent_skins: talent_skins.except(key.to_s), talent_choices: talent_choices.except(key.to_s))
  end

  private
    def talents_fit_level
      if extra_talents.positive?
        errors.add(:base, "At level #{level}, #{name} has room for #{expected_talent_count} #{"talent".pluralize(expected_talent_count)} besides the core; remove one first")
      end
    end

    # A talent already on the sheet stays when the book later limits it to
    # another path ("[Bard Only]" in Preview 6) or drops it (Flurry); only new
    # picks, or a new path, are checked against it.
    def talents_are_choosable
      kept = will_save_change_to_path? ? [] : Array(talent_keys_in_database)
      talent_keys.each do |key|
        talent = Talent.find_by_key(key)
        if talent.nil?
          errors.add(:talent_keys, "include an unknown talent (#{key})")
        elsif talent.core?
          errors.add(:talent_keys, "can't include a core talent (#{talent.name}); it comes from a path")
        elsif talent.prohibited_for?(path) && kept.exclude?(key)
          errors.add(:talent_keys, "can't include #{talent.name} for a #{path}")
        elsif talent.retired? && kept.exclude?(key)
          errors.add(:talent_keys, "can't include #{talent.name}; Preview 6 dropped it")
        elsif eldritch_talent_keys.include?(key)
          errors.add(:talent_keys, "can't include #{talent.name}; it's already an Eldritch Talent")
        end
      end
    end
end
