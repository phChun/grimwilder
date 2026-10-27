# Pools a campaign's optional rules give each character (Campaign::OptionalRules),
# as Talent::Uses under the key "rule", so they're made, refilled and rolled
# like talent pools (Character::TalentUses): Vigor (3d, refreshed by a rest or
# downtime), Armor (1d light or 2d heavy, each session), Supplies and Coins
# (4d, kept until the GM restocks them; Coins can drop 1d first).
module Character::RulePools
  extend ActiveSupport::Concern

  ARMORS = { "light" => 1, "heavy" => 2 }.freeze

  included do
    validates :armor, inclusion: { in: ARMORS.keys }, allow_nil: true
    normalizes :armor, with: ->(value) { value.presence }
  end

  def rule_uses
    return [] unless campaign

    [
      ({ key: "vigor", label: "Vigor", pool: 3, pool_kind: "resource", per: "rest" } if campaign.optional_rule?(:vigor_pool)),
      ({ key: "armor", label: "Armor (#{armor})", pool: ARMORS[armor], pool_kind: "resource", per: "session" } if campaign.optional_rule?(:armor) && armor),
      ({ key: "supplies", label: "Supplies", pool: 4, pool_kind: "resource", per: "never" } if campaign.optional_rule?(:supplies)),
      ({ key: "coins", label: "Coins", pool: 4, pool_kind: "power", per: "never", drop_first: true, bonus_dice: true } if campaign.optional_rule?(:wealth))
    ].compact.map { Talent::Use.from("rule", _1) }
  end

  # Encumbrance (pg. 176): slots of gear beyond main armor and weapons.
  def gear_slots
    2 + brawn.to_i
  end
end
