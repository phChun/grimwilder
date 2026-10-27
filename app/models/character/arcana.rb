# A character's arcana (Arcanum; pg. 41–44). Anyone can hold them, found or
# bought in play; some talents grant them (`arcana:` in config/talents.yml:
# Archivist's 2 minor and 1 major), and the sheet reminds the player of those.
#
# Power pools live in the character's campaign beside talent pools, refilled
# each session (and at downtime), and only while seated.
module Character::Arcana
  extend ActiveSupport::Concern

  included do
    has_many :arcana, class_name: "Arcanum", dependent: :destroy
  end

  # [[grant, how many held]] for each talent that grants arcana.
  def arcana_grants
    [ core_talent_entry, *chosen_talents, *eldritch_talents ].compact.flat_map(&:arcana).map do |grant|
      [ grant, arcana.count { grant.counts?(_1) } ]
    end
  end

  # Creates and renames arcana power pools, and refills them when `refill`
  # (each session, unless it has a unique reset) or when one is new or changes size; pools for arcana that
  # have none, or are used up, go away. Only while seated.
  def refresh_arcana_pools!(refill: false)
    return unless campaign

    # Fresh from the database: an arcana saving itself calls this, and the
    # character's loaded arcana may be older copies.
    with_pools = Arcanum.where(character_id: id, used_at: nil, power_pool: true).to_a
    with_pools.each do |arcanum|
      pool, size = Pool.find_or_initialize_by(arcanum: arcanum), arcanum.pool_size
      pool.assign_attributes(campaign: campaign, character: self, name: "#{name}: #{arcanum.name}", kind: "power", refresh: "session", hidden: false)
      if (refill && !arcanum.unique_reset?) || pool.new_record? || pool.starting_size != size
        pool.assign_attributes(starting_size: size, size: size, phases: [], phase: 0,
          last_dice: [], last_dropped: nil, last_action: nil, last_rolled_by: nil, last_rolled_at: nil)
      end
      pool.save!
    end
    talent_pools.where.not(arcanum_id: nil).where.not(arcanum_id: with_pools.map(&:id)).destroy_all
  end

  # Before each session: a Magnum Opus rolls its touchstones afresh.
  def reset_opus_rolls
    Arcanum.where(character_id: id, source: Arcanum::OPUS).find_each { _1.update!(rolled_touchstones: [], lock_ready: false) }
  end
end
