require "test_helper"

# Arcana (pg. 40–43) and their power pools (Character::Arcana).
class ArcanumTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs) # seated at the Bramblewood
  end

  test "a function, a tier, and touchstones cleaned like the sheet's other words" do
    lantern = @tibbs.arcana.create!(name: "  Lantern of  Echoes ", function: "reveal", tier: "major", touchstones: [ " echo ", "Echo", "", "light" ])

    assert_equal "Lantern of Echoes", lantern.name
    assert_equal %w[ echo light ], lantern.touchstones
    assert_equal %w[ reveal echo light ], lantern.all_touchstones
    assert_equal "Major arcana", lantern.tier_label

    assert_not @tibbs.arcana.build(name: "Odd", function: "juggle").valid?
    assert_not @tibbs.arcana.build(name: "Spark", function: "attack", tier: "trivial").valid?, "trivial is only for expendable arcana"
    assert @tibbs.arcana.build(name: "Spark", function: "attack", tier: "trivial", expendable: true).valid?
    assert_not @tibbs.arcana.build(name: "Spark", function: "attack", tier: "trivial", expendable: true, power_pool: true).valid?
  end

  test "a power pool sized by tier lives in the campaign, beside talent pools" do
    ring = @tibbs.arcana.create!(name: "Ring of Gusts", function: "traverse", tier: "minor", power_pool: true)
    pool = ring.reload.pool

    assert_equal [ 2, 2, "power", "Gibbletibble \"Tibbs\": Ring of Gusts" ], [ pool.starting_size, pool.size, pool.kind, pool.name ]
    assert_equal campaigns(:bramblewood), pool.campaign
    assert_equal @tibbs, pool.character
    assert pool.rolls_as_action?
    assert_not pool.drops_first_for?(gm: true), "only a mythic arcana's pool drops 1d first"

    pool.update!(size: 1)
    ring.update!(name: "Ring of Storms")
    assert_equal [ "Gibbletibble \"Tibbs\": Ring of Storms", 1 ], [ pool.reload.name, pool.size ], "a rename keeps the dice left"

    ring.update!(tier: "mythic")
    assert_equal [ 6, 6 ], [ pool.reload.starting_size, pool.size ]
    assert pool.drops_first_for?(gm: false)

    ring.update!(power_pool: false)
    assert_nil ring.reload.pool
  end

  test "a session refills arcana pools; unseated characters have none" do
    ring = @tibbs.arcana.create!(name: "Ring of Gusts", function: "traverse", tier: "major", power_pool: true)
    ring.pool.update!(size: 1)

    @tibbs.start_session!
    assert_equal 4, ring.reload.pool.size

    @tibbs.update!(campaign: nil)
    assert_nil ring.reload.pool
    @tibbs.update!(campaign: campaigns(:bramblewood))
    assert_equal 4, ring.reload.pool.size, "seated again, the pool comes back"

    @tibbs.refresh_talent_pools!(per: :session)
    assert_equal 1, @tibbs.talent_pools.where(arcanum: ring).count, "talent pools leave arcana pools alone"
  end

  test "expendable arcana are used up, and their pools go with them" do
    scroll = @tibbs.arcana.create!(name: "Scroll of Mending", function: "restore", tier: "minor", expendable: true, power_pool: true)
    assert scroll.pool

    scroll.use_up!
    assert scroll.used?
    assert_nil scroll.reload.pool

    scroll.restore!
    assert scroll.reload.pool
  end

  test "deleting an arcana or the character takes its pool" do
    ring = @tibbs.arcana.create!(name: "Ring of Gusts", function: "traverse", power_pool: true)
    pool_id = ring.pool.id

    ring.destroy!
    assert_not Pool.exists?(pool_id)
  end

  test "Magnum Opus rolls touchstones for the ones not locked in, then locks one in a session" do
    opus = @tibbs.arcana.create!(name: "The Great Work", function: "summon", tier: "mythic", source: "magnum-opus")
    assert opus.opus?
    assert_raises(ArgumentError) { opus.lock_opus_touchstone!("void") }

    opus.roll_opus_touchstones!(random: Random.new(1))
    rolled = opus.rolled_touchstones
    assert_equal 3, rolled.size
    words = Crucible.find("arcana").tables.flat_map { _1.rows.flatten }
    assert rolled.all? { words.include?(_1) }

    opus.lock_opus_touchstone!(rolled.second)
    assert_equal [ rolled.second ], opus.touchstones
    assert_raises(ArgumentError, "one lock a session") { opus.lock_opus_touchstone!(rolled.first) }

    @tibbs.start_session!
    assert_empty opus.reload.rolled_touchstones

    opus.roll_opus_touchstones!
    assert_equal 2, opus.rolled_touchstones.size, "one fewer once one is locked in"
    assert_not_includes opus.rolled_touchstones, rolled.second
  end

  test "talents remind the player of the arcana they grant" do
    @tibbs.update!(level: 2, talent_keys: %w[ archivist lucky ])
    @tibbs.arcana.create!(name: "Ink of Ages", function: "reveal", tier: "minor", source: "archivist")
    @tibbs.arcana.create!(name: "Found Ring", function: "protect", tier: "minor")

    grants = @tibbs.arcana_grants.map { |grant, held| [ grant.to_s(@tibbs.level), held ] }
    assert_equal [ [ "2 minor arcana", 1 ], [ "1 major arcana", 0 ] ], grants

    assert_equal "3 major arcana", Talent.find("infusion").arcana.sole.to_s(2)
    assert Talent.find("infusion").arcana.sole.optional
    assert Talent.find("magnum-opus").arcana.sole.opus
    assert_equal "1 major expendable arcana", Talent.find("trophies").arcana.sole.to_s
  end
end
