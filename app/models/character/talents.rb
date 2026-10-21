# Talents from the catalog (config/talents.yml). The core talent comes from the
# path; the rest are chosen: one at creation and one per new level (pg. 31, 46),
# so a character at level N expects N chosen talents.
module Character::Talents
  extend ActiveSupport::Concern

  included do
    validate :talents_are_choosable
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

  def has_talent?(talent)
    talent_keys.include?(talent.key)
  end

  def add_talent!(key)
    talent = Talent.find(key)
    update!(talent_keys: talent_keys + [ talent.key ]) unless has_talent?(talent)
    talent
  end

  def remove_talent!(key)
    update!(talent_keys: talent_keys - [ key.to_s ], talent_skins: talent_skins.except(key.to_s))
  end

  private
    def talents_are_choosable
      talent_keys.each do |key|
        talent = Talent.find_by_key(key)
        if talent.nil?
          errors.add(:talent_keys, "include an unknown talent (#{key})")
        elsif talent.core?
          errors.add(:talent_keys, "can't include a core talent (#{talent.name}); it comes from a path")
        elsif talent.prohibited_for?(path)
          errors.add(:talent_keys, "can't include #{talent.name} for a #{path}")
        end
      end
    end
end
