# Pools a campaign's optional rules give each character (Campaign::OptionalRules),
# as Talent::Uses under the key "rule", so they're made, refilled and rolled
# like talent pools (Character::TalentUses): Vigor (3d, refreshed by a rest or
# downtime), Armor (1d light or 2d heavy, each session; Bulwark's rework adds
# 2d in place of its own pool), Supplies and Coins (4d, kept until the GM
# restocks them; Coins can drop 1d first, and carousing adds 2d up to 8d).
module Character::RulePools
  extend ActiveSupport::Concern

  ARMORS = { "light" => 1, "heavy" => 2 }.freeze
  BULWARK = "bulwark"
  COINS = "rule/coins"
  MAX_COINS = 8

  included do
    validates :armor, inclusion: { in: ARMORS.keys }, allow_nil: true
    normalizes :armor, with: ->(value) { value.presence }
    after_update_commit :refresh_rule_pools!, if: :saved_change_to_armor?
  end

  def rule_uses
    return [] unless campaign

    armor_dice = ARMORS[armor].to_i + (bulwark_reworked? ? 2 : 0)
    [
      ({ key: "vigor", label: "Vigor", pool: 3, pool_kind: "resource", per: "rest" } if campaign.optional_rule?(:vigor_pool)),
      ({ key: "armor", label: armor_label, pool: armor_dice, pool_kind: "resource", per: "session" } if campaign.optional_rule?(:armor) && armor_dice.positive?),
      ({ key: "supplies", label: "Supplies", pool: 4, pool_kind: "resource", per: "never" } if campaign.optional_rule?(:supplies)),
      ({ key: "coins", label: "Coins", pool: 4, pool_kind: "power", per: "never", drop_first: true, bonus_dice: true } if campaign.optional_rule?(:wealth))
    ].compact.map { Talent::Use.from("rule", _1) }
  end

  # Bulwark's rework under the Armor rule (pg. 176): +2d to the Armor pool,
  # whatever armor is worn, in place of its own pool, and rolling it avoids
  # the consequence instead of lessening it.
  def bulwark_reworked?
    campaign&.optional_rule?(:armor) && [ *chosen_talents, *eldritch_talents ].any? { _1.key == BULWARK }
  end

  # Makes the rule pools a table has just turned on, and removes those it
  # turned off, without touching anyone's other pools or what's left in them.
  def refresh_rule_pools!
    return unless campaign

    uses = rule_uses
    uses.each do |use|
      pool = talent_pools.find_or_initialize_by(use_key: use.id)
      size = use.pool_at(level)
      if pool.new_record?
        pool.update!(campaign: campaign, name: "#{name}: #{use.label}", kind: use.pool_kind, refresh: use.per, starting_size: size, size: size)
      else
        pool.update!(name: "#{name}: #{use.label}", starting_size: [ size, pool.size ].max, size: [ pool.size, size ].min)
      end
    end
    talent_pools.where("use_key LIKE 'rule/%'").where.not(use_key: uses.map(&:id)).destroy_all
    talent_pools.where(use_key: "#{BULWARK}/#{BULWARK}").destroy_all if bulwark_reworked?
  end

  # Wealth (pg. 177): carousing by selling off treasure, or as the GM sees
  # fit, adds 2d to the Coins pool, up to 8d.
  # Expanded downtime replaces carousing, so it's gone while that rule's on.
  def add_coins!(by:)
    raise ArgumentError, "#{campaign.name} uses Expanded downtime, which replaces carousing." if carousing_replaced?
    pool = talent_pools.find_by(use_key: COINS) or raise ArgumentError, "#{short_name} has no Coins pool."
    raise ArgumentError, "#{short_name}'s Coins are at #{MAX_COINS}d." if pool.size >= MAX_COINS

    size = [ pool.size + 2, MAX_COINS ].min
    pool.update!(size: size, starting_size: [ pool.starting_size, size ].max)
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name}'s Coins grow to #{size}d.") if campaign
  end

  def carousing_replaced?
    campaign&.expanded_downtime? || false
  end

  # Encumbrance (pg. 176): slots of gear beyond main armor and weapons.
  def gear_slots
    2 + brawn.to_i
  end

  private
    def armor_label
      [ ("#{armor}" if armor), ("+2d Bulwark" if bulwark_reworked?) ].compact.join(", ").then { "Armor (#{_1})" }
    end
end
