# Talents from the catalog (config/talents.yml). The core talent comes from the
# path; the rest are chosen: one at creation and one per new level (pg. 31, 46),
# so a character at level N has at most N chosen talents, from any path (pg. 52).
# Swapping one means removing it first.
module Character::Talents
  extend ActiveSupport::Concern

  included do
    validate :talents_are_choosable
    # Only when talents or level change, so a sheet that's already over (from
    # before the limit) can still take spark, harm and rolls.
    validate :talents_fit_level, if: -> { will_save_change_to_talent_keys? || will_save_change_to_level? }
  end

  def core_talent_entry
    Talent.core_for(path)
  end

  def chosen_talents
    talent_keys.filter_map { |key| Talent.find_by_key(key) }
  end

  def expected_talent_count
    level
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

    def talents_are_choosable
      talent_keys.each do |key|
        talent = Talent.find_by_key(key)
        if talent.nil?
          errors.add(:talent_keys, "include an unknown talent (#{key})")
        elsif talent.core?
          errors.add(:talent_keys, "can't include a core talent (#{talent.name}); it comes from a path")
        elsif talent.prohibited_for?(path)
          errors.add(:talent_keys, "can't include #{talent.name} for a #{path}")
        elsif eldritch_talent_keys.include?(key)
          errors.add(:talent_keys, "can't include #{talent.name}; it's already an Eldritch Talent")
        end
      end
    end
end
