# The optional rules a GM turns on for the table, in settings (P6 pg. 175–180).
# Rules a character opts into with the GM's say-so (stat progression, legacy
# cores, level 0) stay on the character; these change what the table offers:
#
# - `weapon_styles` (Gear, pg. 177): weapons have two styles. Character forms
#   ask for them only at a table that uses the rule, or when they're already
#   filled in.
module Campaign::OptionalRules
  extend ActiveSupport::Concern

  RULES = { "weapon_styles" => "Weapon styles: each PC's weapons have two styles (pg. 177)" }.freeze

  def optional_rules=(value)
    super(Array(value).map(&:to_s) & RULES.keys)
  end

  def optional_rule?(rule)
    optional_rules.include?(rule.to_s)
  end
end
