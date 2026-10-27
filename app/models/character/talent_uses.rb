# What a character's talents give each session or scene (Talent::Use): counts
# spent so far (talent_uses, keyed by Talent::Use#id), extra thread, and talent
# pools kept in the character's campaign (Grenades, Wild Shape…). Starting a
# session resets all of it; ending a scene resets the per-scene ones.
module Character::TalentUses
  extend ActiveSupport::Concern

  included do
    has_many :talent_pools, class_name: "Pool", dependent: :destroy
  end

  TALLY_MAX = 99

  # Rule pools (Character::RulePools) ride along, so they're made and refilled the same way.
  def talent_use_list
    [ core_talent_entry, *chosen_talents, *eldritch_talents ].compact.flat_map(&:uses) + rule_uses
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

  # A count, or for a use named by a choice (Hidden Magic's words), the names burned.
  def uses_spent(use)
    spent = talent_uses.fetch(use.id, 0)
    spent.is_a?(Array) ? spent.size : spent.to_i
  end

  # One label per box for a named use: the character's picks in order, then
  # nil for boxes with no pick yet.
  def use_box_names(use)
    return use.names if use.names

    picks = use.named? ? picks_for(talent_entry(use.talent_key).choice(use.named_by)) : []
    Array.new(use.count_at(level)) { picks[_1] }
  end

  def burned_names(use)
    Array(talent_uses[use.id]).grep(String)
  end

  # How many boxes a count has now: its count at this level, less anything
  # its `less_by` takes off (1 smite for each tenet in violation).
  def use_count(use)
    return if use.tally?

    [ use.count_at(level) - (use.less_by ? public_send(use.less_by) : 0), 0 ].max
  end

  def uses_left(use)
    use.tally? ? Float::INFINITY : [ use_count(use) - uses_spent(use), 0 ].max
  end

  # Awakened Mind's instability: the thorns on the last box ticked.
  def track_thorns(use)
    spent = uses_spent(use)
    spent.positive? ? use.track_at(level)[spent - 1].to_i : 0
  end

  # Sets how many of a talent's uses are spent this session or scene.
  def spend_use!(use_id, spent:)
    use = use_counters.find { _1.id == use_id } or raise ArgumentError, "#{name} has no talent use #{use_id.inspect}."
    update!(talent_uses: talent_uses.merge(use.id => spent.to_i.clamp(0, use_count(use) || TALLY_MAX)))
    use
  end

  # Burns or restores one named box (a word of power) by its name.
  def toggle_named_use!(use_id, name)
    use = use_counters.select(&:named?).find { _1.id == use_id } or raise ArgumentError, "#{self.name} has no named talent use #{use_id.inspect}."
    raise ArgumentError, "#{name.inspect} isn't one of #{self.name}'s #{use.label.downcase}." unless use_box_names(use).compact.include?(name)

    burned = burned_names(use)
    update!(talent_uses: talent_uses.merge(use.id => burned.include?(name) ? burned - [ name ] : burned + [ name ]))
    use
  end

  # per: :session resets the per-session and per-scene uses; :scene only the
  # per-scene ones; :rest the ones a rest clears (a vassal's or companion's
  # damage). Charges kept until spent never reset. Doesn't save.
  def reset_talent_uses(per:)
    self.talent_uses = talent_uses.except(*use_counters.select { _1.resets_with?(per) }.map(&:id))
  end

  # Creates, resizes and refills talent pools for this level: all of them for
  # :session, the per-scene ones for :scene, the per-rest ones for :rest. Pools
  # for talents the character no longer has go away. A session refills arcana
  # pools too (Character::Arcana).
  def refresh_talent_pools!(per:)
    return unless campaign

    pool_uses.select { per == :session || (per == :rest ? _1.per == "rest" : _1.per_scene?) || _1.per == "never" }.each do |use|
      size = use.pool_at(level).clamp(1, Pool::MAX_SIZE)
      pool = talent_pools.find_or_initialize_by(use_key: use.id)
      # Kept until spent (Pact's Patience, Supplies): made once, then only
      # renamed and grown, never refilled by a session. A per-rest pool (Vigor)
      # is made by a session but refilled only by a rest.
      next pool.update!(campaign: campaign, name: "#{name}: #{use.label}", starting_size: size) if pool.persisted? && (use.per == "never" || (use.per == "rest" && per != :rest))

      pool.update!(
        campaign: campaign, name: "#{name}: #{use.label}", kind: use.pool_kind, refresh: use.per, hidden: false,
        starting_size: size, size: size, phases: [], phase: 0, refills_used: 0,
        last_dice: [], last_dropped: nil, last_action: nil, last_rolled_by: nil, last_rolled_at: nil
      )
    end
    talent_pools.where(arcanum_id: nil, made_by_talent: false).where.not(use_key: pool_uses.map(&:id)).destroy_all
    talent_pools.where(made_by_talent: true).select { per == :session || _1.refresh == per.to_s }.each(&:destroy)
    refresh_arcana_pools!(refill: true) if per == :session
  end
end
