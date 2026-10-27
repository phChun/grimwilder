# The optional rules a GM turns on for the table, in settings (P6 pg. 175–178).
# Rules a character opts into with the GM's say-so (stat progression, legacy
# cores, level 0) stay on the character; these change what the table offers:
#
# - `weapon_styles` (Gear, pg. 177): character forms ask for two styles.
# - `vigor_pool`, `armor`, `supplies`, `wealth` (pg. 175–176): pools each
#   character holds (Character::RulePools).
# - `encumbrance` (pg. 176): the sheet counts gear slots, 2 + Brawn.
# - `milestone_levels` (pg. 177): no XP after a session; the GM levels the
#   party up after a major arc (Campaign#milestone!).
# - `focused_growth` (pg. 177): twice the XP to level, and the end of a
#   session can give bonus XP for what happened in play.
# - `rest_resets` (pg. 175): sessions don't reset spark, thread or talents;
#   the GM's Reset does, at a rest (Campaign#rest_reset!).
# - `token_initiative`, `active_vigilance`, `writers_room` (pg. 175, 178): how
#   the table plays; listed so everyone knows, nothing to track.
module Campaign::OptionalRules
  extend ActiveSupport::Concern

  # rule => [name, page, what it does]
  RULES = {
    "weapon_styles" => [ "Weapon styles", 177, "Each PC's weapons have two styles that shape the fiction." ],
    "vigor_pool" => [ "Vigor pool", 175, "For games without healing magic: a 3d Vigor pool each, rolled to clear 1 harm, refreshed by a rest or downtime." ],
    "armor" => [ "Armor", 176, "Light armor gives a 1d Armor pool each session, heavy 2d: roll it after a physical consequence to lessen it." ],
    "supplies" => [ "Supplies", 176, "A 4d Supplies pool each for common items and rations, rolled with heavy use and time away from civilization." ],
    "wealth" => [ "Wealth", 176, "A 4d Coins pool each for larger purchases; drop 1d first for huge expenses." ],
    "encumbrance" => [ "Encumbrance", 176, "Room for 2 + Brawn slots of gear, beyond main armor and weapons." ],
    "milestone_levels" => [ "Milestone levels", 177, "No XP after sessions: the party levels up after completing a major group arc." ],
    "focused_growth" => [ "Focused growth", 177, "Twice the XP to level, with a chance of bonus XP at the end of each session." ],
    "rest_resets" => [ "Rest resets", 175, "Talents, thread and spark reset at a rest instead of each session." ],
    "token_initiative" => [ "Token initiative", 175, "In an intense moment, each player gets 2 tokens to spend on story beats; all regain them once they're spent." ],
    "active_vigilance" => [ "Active vigilance", 178, "A story roll for what a PC notices: perfect, a reveal; messy, a hint; grim, the GM strikes." ],
    "writers_room" => [ "Writers' room", 178, "Tangles and thread needn't come from vantage; only details that benefit the party cost thread." ]
  }.freeze

  def optional_rules=(value)
    super(Array(value).map(&:to_s) & RULES.keys)
  end

  def optional_rule?(rule)
    optional_rules.include?(rule.to_s)
  end

  # [[name, page, what it does]] for the rules this table uses, in RULES order.
  def rules_in_play
    RULES.select { |rule, _| optional_rule?(rule) }.values
  end
end
