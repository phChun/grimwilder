require "test_helper"

# Oathsworn's tenets and Affirmation, Monster Menagerie's creature, Archivist's
# arcana pools, and the optional path builders.
class TalentFeaturesTest < ActiveSupport::TestCase
  setup do
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @pip = identities(:pip)
    @campaign = campaigns(:bramblewood)
  end

  test "a tenet is slashed, filled, then broken; each in violation costs a smite, and atoning clears one" do
    @tibbs.update!(path: "Paladin", talent_keys: [ "aegis" ])
    @tibbs.choose_for_talent!("oathsworn", "tenets" => [ "never flee", "protect the weak", "speak true" ])
    smite = @tibbs.use_counters.find { _1.key == "smite" }
    assert_equal 3, @tibbs.use_count(smite)

    @tibbs.violate_tenet!("never flee", by: @pip)
    @tibbs.violate_tenet!("never flee", by: @pip)
    assert_equal [ { "never flee" => "heavy" }, 2 ], [ @tibbs.tenet_violations, @tibbs.use_count(smite) ]
    assert_match "is in heavy violation of a tenet: never flee", @campaign.rolls.note.last.question

    @tibbs.start_session!
    assert_equal({ "never flee" => "heavy" }, @tibbs.reload.tenet_violations, "a session doesn't atone")

    @tibbs.atone_tenet!("never flee", by: @pip)
    assert_equal 3, @tibbs.use_count(smite)
    assert_raises(ArgumentError) { @tibbs.violate_tenet!("not a tenet", by: @pip) }
  end

  test "a second broken tenet makes an Oathbreaker" do
    @tibbs.update!(path: "Paladin", talent_keys: [ "aegis" ])
    @tibbs.choose_for_talent!("oathsworn", "tenets" => [ "never flee", "protect the weak", "speak true" ])
    3.times { @tibbs.violate_tenet!("never flee", by: @pip) }
    assert_raises(ArgumentError) { @tibbs.atone_tenet!("never flee", by: @pip) }
    assert_not @tibbs.oathbroken?

    3.times { @tibbs.violate_tenet!("speak true", by: @pip) }
    assert @tibbs.oathbroken?
    assert_equal "talented", @tibbs.core_talent_entry.key
  end

  test "Affirmation gives another character at the table spark, once a session" do
    @tibbs.update!(path: "Paladin", talent_keys: [ "aegis" ])
    @bram.update!(spark: 0)
    @tibbs.affirm!(@bram, by: @pip)
    assert_equal 1, @bram.reload.spark
    assert_match "Affirmation: Bram takes spark", @campaign.rolls.note.last.question
    assert_raises(ArgumentError) { @tibbs.affirm!(@bram, by: @pip) }
    assert_raises(ArgumentError) { characters(:tibbs).tap { _1.update!(talent_uses: {}) }.affirm!(@tibbs, by: @pip) }
  end

  test "Monster Menagerie picks which creature answers" do
    @tibbs.update!(path: "Summoner", level: 2, talent_keys: %w[ monster-menagerie lucky ])
    @tibbs.choose_for_talent!("monster-menagerie", "creatures" => [ "Grimfang", "Mote" ])
    @tibbs.answer_with!("Mote", by: @pip)
    assert_equal "Mote", @tibbs.answering_creature
    assert_raises(ArgumentError) { @tibbs.answer_with!("Nobody", by: @pip) }
  end

  test "Archivist: an arcana's power pool drops 1 fewer die, unless it's the last" do
    @tibbs.update!(level: 2, talent_keys: %w[ archivist lucky ])
    ring = @tibbs.arcana.create!(name: "Ring of Gusts", function: "traverse", tier: "major", power_pool: true)
    pool = ring.reload.pool
    pool.roll!(by: @pip, random: FixedDice.new([ 1, 2, 5, 6 ]))
    assert_equal 3, pool.reload.size, "two 1–3s, one of them kept"

    pool.update!(size: 1)
    pool.roll!(by: @pip, random: FixedDice.new([ 2 ]))
    assert_equal 0, pool.reload.size, "the last die still drops"
  end

  test "the optional path builders are offered, never asked for" do
    { "inspiration" => %w[ method method-learning ], "frenzy" => %w[ source source-disdain scars ], "panache" => %w[ creed ], "hidden-magic" => %w[ affliction ] }.each do |key, choices|
      talent = Talent.find(key)
      choices.each { assert talent.choice(_1).optional?, "#{key}/#{_1}" }
    end
    assert_equal %w[ druidic_tells weapon_origin favorite_traps ], %w[ wild-shape weapon-mastery quarry ].map { Talent.find(_1).crucible }
    assert_equal [ "thorns", "petals" ], Crucible.find("druidic_tells").tables.sole.then { [ _1.cell(1, 1), _1.cell(6, 6) ] }
    assert_equal "patched many times", Crucible.find("weapon_origin").tables.sole.cell(6, 3)
    assert_equal [ "injuring", "proximity" ], Crucible.find("favorite_traps").tables.map { _1.cell(6, 1) }
  end
end
