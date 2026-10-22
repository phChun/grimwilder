require "test_helper"

class CharacterTalentUsesTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @ash = identities(:gwen).characters.create!(name: "Ash", path: "Fighter", brawn: 3, agility: 2, wits: 2, presence: 1,
      campaign: @campaign, talent_keys: [ "bulwark" ])
  end

  test "uses come from the core talent and chosen talents" do
    assert_equal [ "weapon-mastery/mastery" ], @ash.use_counters.map(&:id)
    assert_equal [ "bulwark/bulwark" ], @ash.pool_uses.map(&:id)
    assert_equal 0, @ash.talent_thread
    assert_equal 1, characters(:tibbs).talent_thread, "According to Plan"
  end

  test "spending ticks uses, within what the level allows" do
    @ash.spend_use!("weapon-mastery/mastery", spent: 1)
    assert_equal 1, @ash.reload.uses_left(@ash.use_counters.sole)

    @ash.spend_use!("weapon-mastery/mastery", spent: 9)
    assert_equal 2, @ash.reload.talent_uses["weapon-mastery/mastery"]
    assert_raises(ArgumentError) { @ash.spend_use!("inspiration/inspiration", spent: 1) }
  end

  test "a session start resets uses and creates talent pools sized for the level" do
    @ash.update!(level: 3, talent_keys: [ "bulwark", "iron-will", "control" ], talent_uses: { "weapon-mastery/mastery" => 2, "control/control" => 1 })

    PlaySession.start!(@campaign, characters: [ @ash ], by: identities(:gwen))
    assert_empty @ash.reload.talent_uses
    pools = @ash.talent_pools.order(:use_key)
    assert_equal [ [ "Ash: Bulwark", "resource", 2, "session" ], [ "Ash: Iron Will", "resource", 2, "session" ] ],
      pools.map { [ _1.name, _1.kind, _1.size, _1.refresh ] }
    assert pools.all? { _1.campaign == @campaign }
    assert_equal 3, @ash.use_counters.find { _1.key == "mastery" }.count_at(@ash.level), "grew at level 3"
  end

  test "ending a scene resets only per-scene uses and pools" do
    @ash.update!(level: 2, talent_keys: [ "bulwark", "control" ])
    session = PlaySession.start!(@campaign, characters: [ @ash ], by: identities(:gwen))
    bulwark = @ash.talent_pools.sole
    bulwark.roll!(by: identities(:gwen), random: FixedDice.new([ 1, 6 ]))
    @ash.update!(talent_uses: { "weapon-mastery/mastery" => 2, "control/control" => 1 })

    Scene.start!(session, title: "The bridge", by: identities(:gwen)).end!(by: identities(:gwen))
    assert_equal({ "control/control" => 1 }, @ash.reload.talent_uses, "mastery resets each scene; control each session")
    assert_equal 1, bulwark.reload.size, "Bulwark is per session"
  end

  test "per-scene talent pools refill when a scene ends" do
    druid = identities(:pip).characters.create!(name: "Fen", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign, talent_keys: [ "awaken" ])
    session = PlaySession.start!(@campaign, characters: [ druid ], by: identities(:gwen))
    wild_shape = druid.talent_pools.sole
    wild_shape.roll!(by: identities(:pip), random: FixedDice.new([ 1, 1 ]))
    assert wild_shape.depleted?

    Scene.start!(session, title: "The grove", by: identities(:gwen)).end!(by: identities(:gwen))
    assert_equal 2, wild_shape.reload.size
  end

  test "dropping a talent removes its pool at the next session" do
    PlaySession.start!(@campaign, characters: [ @ash ], by: identities(:gwen)).end!(by: identities(:gwen))
    assert_equal 1, @ash.talent_pools.count

    @ash.update!(talent_keys: [ "control" ])
    PlaySession.start!(@campaign, characters: [ @ash ], by: identities(:gwen))
    assert_equal 0, @ash.talent_pools.count
  end

  test "thread talents raise the thread a session resets to" do
    tibbs = characters(:tibbs)
    tibbs.update!(thread: 0)

    PlaySession.start!(@campaign, characters: [ tibbs ], by: identities(:gwen))
    assert_equal 3, tibbs.reload.thread
    tibbs.thread = 4
    assert_not tibbs.valid?
  end
end
