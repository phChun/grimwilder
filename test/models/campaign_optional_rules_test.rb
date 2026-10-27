require "test_helper"

# P6's optional rules a GM turns on for the table (Campaign::OptionalRules).
class CampaignOptionalRulesTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @gwen, @pip = identities(:gwen), identities(:pip)
  end

  test "rule pools: Vigor refreshes only with a rest, Armor follows the armor worn, Supplies and Coins are kept" do
    @campaign.update!(optional_rules: %w[ vigor_pool armor supplies wealth ])
    @tibbs.update!(armor: "heavy")
    @tibbs.refresh_talent_pools!(per: :session)
    pools = @tibbs.talent_pools.index_by(&:use_key)
    assert_equal({ "rule/vigor" => 3, "rule/armor" => 2, "rule/supplies" => 4, "rule/coins" => 4 }, pools.transform_values(&:size))
    assert pools["rule/coins"].drops_first_for?(gm: false), "drop 1d first for a huge expense"
    assert_not pools["rule/coins"].rolls_as_action?

    @tibbs.talent_pools.update_all(size: 1)
    @tibbs.refresh_talent_pools!(per: :session)
    assert_equal({ "rule/vigor" => 1, "rule/armor" => 2, "rule/supplies" => 1, "rule/coins" => 1 }, @tibbs.talent_pools.reload.to_h { [ _1.use_key, _1.size ] })

    @tibbs.rest!(by: @gwen)
    assert_equal 3, @tibbs.talent_pools.find_by!(use_key: "rule/vigor").size

    @campaign.update!(optional_rules: [])
    @tibbs.reload.refresh_talent_pools!(per: :session)
    assert_empty @tibbs.talent_pools.where("use_key LIKE 'rule/%'")
  end

  test "rest resets: a session leaves spark, thread and talents; the GM's Reset does it, with 1 harm and 2 suspense" do
    @campaign.update!(optional_rules: %w[ rest_resets ], suspense: 0)
    @tibbs.update!(spark: 0, thread: 0, bloodied: true, rattled: true, desperate: true)
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: @gwen)
    session.end!(by: @gwen)
    PlaySession.start!(@campaign, characters: [ @tibbs ], by: @gwen)
    assert_equal [ 0, 0 ], [ @tibbs.reload.spark, @tibbs.thread ]

    @campaign.reload.rest_reset!(by: @gwen)
    @tibbs.reload
    assert_equal [ 1, 3, false, true ], [ @tibbs.spark, @tibbs.thread, @tibbs.desperate, @tibbs.bloodied ], "the worst harm heals"
    assert_equal 3, @campaign.reload.suspense, "1 from session 2, then 2 from the reset"
    assert_equal "Reset", @campaign.rolls.marker.last.name
  end

  test "milestone levels: no XP after a session; the GM levels the party up" do
    @campaign.update!(optional_rules: %w[ milestone_levels ])
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: @gwen)
    assert_empty session.end!(by: @gwen, standout: true)
    assert_equal [ 1, 0 ], [ @tibbs.reload.level, @tibbs.xp ]

    assert_includes @campaign.milestone!(by: @gwen), @tibbs
    assert_equal 2, @tibbs.reload.level
    assert_equal "Milestone", @campaign.rolls.marker.last.name
  end

  test "focused growth: twice the XP to level, and bonus XP for what happened in play" do
    @campaign.update!(optional_rules: %w[ focused_growth ])
    assert_equal 4, @tibbs.xp_to_next_level
    session = PlaySession.start!(@campaign, characters: [ @tibbs ], by: @gwen)
    session.end!(by: @gwen, bonus: [ @tibbs.id.to_s ])
    assert_equal [ 1, 2 ], [ @tibbs.reload.level, @tibbs.xp ]
  end

  test "rules in play, in the book's order, and unknown ones dropped" do
    @campaign.update!(optional_rules: %w[ encumbrance nonsense weapon_styles ])
    assert_equal %w[ weapon_styles encumbrance ], @campaign.optional_rules.sort_by { Campaign::OptionalRules::RULES.keys.index(_1) }
    assert_equal [ "Weapon styles", "Encumbrance" ], @campaign.rules_in_play.map(&:first)
    assert_equal 3, @tibbs.gear_slots
  end
end
