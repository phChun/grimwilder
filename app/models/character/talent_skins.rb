# Re-skinned talents. The book encourages re-skinning a talent to fit the
# character (pg. 52: a wizard's Bulwark as a magical shield), so the owner or
# the campaign's GM can give any of the character's talents its own name,
# summary and text. The mechanics (uses, pools) stay the book's.
#
# talent_skins: { "bulwark" => { "name" => "Arcane Ward", "summary" => "…", "text" => "…" } }.
# A blank field falls back to the book's.
module Character::TalentSkins
  LIMITS = { "name" => 60, "summary" => 140, "text" => 4000 }.freeze

  # The core talent, then the chosen ones, each wearing its skin.
  def talent_entries
    [ core_talent_entry, *chosen_talents ].compact.map { Character::SkinnedTalent.new(_1, talent_skins[_1.key]) }
  end

  def talent_entry(key)
    talent_entries.find { _1.key == key.to_s } or raise ActiveRecord::RecordNotFound, "#{name} has no talent #{key.inspect}"
  end

  # Saves the non-blank fields; all blank resets the talent to the book's.
  def reskin_talent!(key, attributes)
    talent = talent_entry(key)
    skin = LIMITS.to_h { |field, limit| [ field, attributes[field].to_s.strip.truncate(limit, omission: "") ] }.compact_blank
    skin["name"] = skin["name"].squish if skin["name"]
    skin["summary"] = skin["summary"].squish if skin["summary"]
    skin.delete_if { |field, value| value == talent.book.public_send(field) }

    update!(talent_skins: skin.empty? ? talent_skins.except(talent.key) : talent_skins.merge(talent.key => skin))
  end

  def reset_talent_skin!(key)
    update!(talent_skins: talent_skins.except(talent_entry(key).key))
  end
end
