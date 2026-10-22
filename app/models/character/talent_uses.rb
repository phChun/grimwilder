# What a character's talents give each session or scene (Talent::Use): counts
# spent so far (talent_uses, keyed by Talent::Use#id), extra thread, and talent
# pools kept in the character's campaign (Grenades, Wild Shape…). Starting a
# session resets all of it; ending a scene resets the per-scene ones.
module Character::TalentUses
  extend ActiveSupport::Concern

  included do
    has_many :talent_pools, class_name: "Pool", dependent: :destroy
  end

  def talent_use_list
    [ core_talent_entry, *chosen_talents, *eldritch_talents ].compact.flat_map(&:uses)
  end

  def use_counters
    talent_use_list.select(&:counter?)
  end

  def pool_uses
    talent_use_list.select(&:pool?)
  end

  def talent_thread
    talent_use_list.select(&:thread?).sum(&:thread)
  end

  def uses_spent(use)
    talent_uses.fetch(use.id, 0).to_i
  end

  def uses_left(use)
    use.count_at(level) - uses_spent(use)
  end

  # Sets how many of a talent's uses are spent this session or scene.
  def spend_use!(use_id, spent:)
    use = use_counters.find { _1.id == use_id } or raise ArgumentError, "#{name} has no talent use #{use_id.inspect}."
    update!(talent_uses: talent_uses.merge(use.id => spent.to_i.clamp(0, use.count_at(level))))
    use
  end

  # per: :session resets every use; :scene only the per-scene ones. Doesn't save.
  def reset_talent_uses(per:)
    scene_ids = use_counters.select(&:per_scene?).map(&:id)
    self.talent_uses = per == :session ? {} : talent_uses.except(*scene_ids)
  end

  # Creates, resizes and refills talent pools for this level: all of them for
  # :session, the per-scene ones for :scene. Pools for talents the character no
  # longer has go away.
  def refresh_talent_pools!(per:)
    return unless campaign

    pool_uses.select { per == :session || _1.per_scene? }.each do |use|
      size = use.pool_at(level).clamp(1, Pool::MAX_SIZE)
      talent_pools.find_or_initialize_by(use_key: use.id).update!(
        campaign: campaign, name: "#{name}: #{use.label}", kind: use.pool_kind, refresh: use.per, hidden: false,
        starting_size: size, size: size, phases: [], phase: 0,
        last_dice: [], last_dropped: nil, last_action: nil, last_rolled_by: nil, last_rolled_at: nil
      )
    end
    talent_pools.where.not(use_key: pool_uses.map(&:id)).destroy_all
  end
end
