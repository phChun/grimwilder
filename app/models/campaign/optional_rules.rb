# The optional rules a GM turns on for the table, in settings (pg. 175–179),
# grouped there by GROUPS. Stat progression, legacy cores and level 0 are the
# GM's say-so for options each character then takes up on their sheet
# (Character#rule_allows?); the rest change what the table offers:
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
# - `expanded_downtime` (pg. 142): the GM picks each character's downtime
#   action (Campaign::DowntimeActions); carousing goes.
# - `token_initiative`, `active_vigilance`, `writers_room` (pg. 175, 178): how
#   the table plays; listed so everyone knows, nothing to track.
module Campaign::OptionalRules
  extend ActiveSupport::Concern

  included do
    # Turning a rule on or off makes or removes its pools for the party right away.
    after_update_commit -> { characters.played.each(&:refresh_rule_pools!) }, if: :saved_change_to_optional_rules?
  end

  # rule => [name, page, what it does]
  RULES = {
    "stat_progression" => [ "Stat progression", 175, "Once, a character can give up a talent for +1 to a stat (to a max of 3)." ],
    "legacy_cores" => [ "Legacy core talents", 179, "The Fighter, Psion and Bard may use their older core talents." ],
    "level_zero" => [ "Level 0", 177, "New characters may start at level 0: no core talent and 3 stat points, until their first XP." ],
    "weapon_styles" => [ "Weapon styles", 177, "Each PC's weapons have two styles that shape the fiction." ],
    "vigor_pool" => [ "Vigor pool", 175, "For games without healing magic: a 3d Vigor pool each, rolled to clear 1 harm, refreshed by a rest or downtime." ],
    "armor" => [ "Armor", 176, "Light armor gives a 1d Armor pool each session, heavy 2d: roll it after a physical consequence to lessen it." ],
    "supplies" => [ "Supplies", 176, "A 4d Supplies pool each for common items and rations, rolled with heavy use and time away from civilization." ],
    "wealth" => [ "Wealth", 176, "A 4d Coins pool each for larger purchases; drop 1d first for huge expenses." ],
    "encumbrance" => [ "Encumbrance", 176, "Room for 2 + Brawn slots of gear, beyond main armor and weapons." ],
    "milestone_levels" => [ "Milestone levels", 177, "No XP after sessions: the party levels up after completing a major group arc." ],
    "focused_growth" => [ "Focused growth", 177, "Twice the XP to level, with a chance of bonus XP at the end of each session." ],
    "rest_resets" => [ "Rest resets", 175, "Talents, thread and spark reset at a rest instead of each session." ],
    "expanded_downtime" => [ "Expanded downtime", 142, "In downtime each PC rests, plans ahead, pursues a goal, unwinds or ventures (two if they sell a treasure), instead of carousing and everyone healing." ],
    "token_initiative" => [ "Token initiative", 175, "In an intense moment, each player gets 2 tokens to spend on story beats; all regain them once they're spent." ],
    "active_vigilance" => [ "Active vigilance", 178, "A story roll for what a PC notices: perfect, a reveal; messy, a hint; grim, the GM strikes." ],
    "writers_room" => [ "Writers' room", 178, "Tangles and thread needn't come from vantage; only details that benefit the party cost thread." ]
  }.freeze

  # How settings lays the rules out.
  GROUPS = {
    "Characters" => %w[ stat_progression legacy_cores level_zero weapon_styles ],
    "Pools and gear" => %w[ vigor_pool armor supplies wealth encumbrance ],
    "Advancement and rests" => %w[ milestone_levels focused_growth rest_resets expanded_downtime ],
    "At the table" => %w[ token_initiative active_vigilance writers_room ]
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
