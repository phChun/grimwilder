require "test_helper"

# What talents keep track of (talent-ui brief §E): uses that reset at other
# times, named and tallied boxes, instability, pools that refill or are made
# when used, omens, frenzy, quarries, smite and Flesh Wounds.
class TalentTrackersTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @pip = identities(:pip)
  end

  def use(key)
    @tibbs.use_counters.find { _1.key == key } || @tibbs.pool_uses.find { _1.key == key }
  end

  test "uses reset when they say: charges never, a companion's damage at a rest, a vassal's at the scene's end" do
    @tibbs.update!(path: "Summoner", talent_keys: [ "primordial-bonds", "animal-companion" ], level: 2)
    @tibbs.toggle_named_use!("primordial-bonds/charges", "Fire")
    @tibbs.toggle_named_use!("animal-companion/damage", "Hurt")
    @tibbs.toggle_named_use!("vassal/damage", "Mark")

    @tibbs.end_scene!
    burned = ->(id) { @tibbs.burned_names(@tibbs.use_counters.find { _1.id == id }) }
    assert_equal [ [ "Fire" ], [ "Hurt" ], [] ], %w[ primordial-bonds/charges animal-companion/damage vassal/damage ].map(&burned)
    @tibbs.rest!
    assert_empty burned.("animal-companion/damage")
    @tibbs.start_session!
    assert_equal [ "Fire" ], burned.("primordial-bonds/charges"), "a charge is kept until spent"
  end

  test "Mischief Maker's story roll takes +1t for each overload before it" do
    @tibbs.update!(talent_keys: [ "mischief-maker" ])
    @tibbs.call_talent_roll!("mischief-maker", 0, by: @pip)
    first = @campaign.roll_calls.last
    assert_equal 0, first.thorns
    first.cancel!(by: @pip)

    @tibbs.call_talent_roll!("mischief-maker", 0, by: @pip)
    assert_equal [ 1, 2 ], [ @campaign.roll_calls.last.thorns, @tibbs.reload.uses_spent(use("overloads")) ]
  end

  test "Awakened Mind: instability adds its thorns to psionic spells, and a full track allows no more potent ones" do
    @tibbs.update!(path: "Psion", talent_keys: [])
    roll = @tibbs.roll!("wits", by: @pip, bonuses: %w[ awakened-mind/cast awakened-mind/potent ], random: FixedDice.new([ 4, 5 ]))
    assert_empty roll.thorns, "the first potent spell is at +0t"
    assert_equal 1, @tibbs.reload.uses_spent(use("instability"))

    @tibbs.update!(talent_uses: { "awakened-mind/instability" => 2 })
    roll = @tibbs.roll!("wits", by: @pip, bonuses: %w[ awakened-mind/cast ], panache: 0, random: FixedDice.new([ 4, 5, 3 ]))
    assert_equal [ [ 3 ], [ "instability" ] ], [ roll.thorns, roll.damage_reasons ]

    @tibbs.update!(talent_uses: { "awakened-mind/instability" => 3 })
    assert_equal 2, @tibbs.track_thorns(use("instability"))
    error = assert_raises(ArgumentError) { @tibbs.roll!("wits", by: @pip, bonuses: %w[ awakened-mind/potent ]) }
    assert_match "No instability left", error.message
    @tibbs.start_session!
    assert_equal 0, @tibbs.track_thorns(use("instability"))
  end

  test "Pact's Patience never refills with a session, and comes back at 0d; the Vassal's once" do
    @tibbs.update!(path: "Warlock", talent_keys: [])
    @tibbs.refresh_talent_pools!(per: :session)
    patience = @tibbs.talent_pools.sole
    patience.update!(size: 1)
    @tibbs.start_session!
    assert_equal 1, patience.reload.size

    patience.roll!(by: @pip, random: FixedDice.new([ 2 ]))
    assert_equal [ 8, true ], [ patience.reload.size, @campaign.rolls.last.refilled? ]
    assert_match "Then it refills to 8d", ApplicationController.helpers.pool_roll_summary(@campaign.rolls.last)

    @tibbs.update!(path: "Summoner")
    @tibbs.refresh_talent_pools!(per: :session)
    vassal = @tibbs.talent_pools.find_by!(use_key: "vassal/vassal")
    2.times { vassal.update!(size: 1) && vassal.roll!(by: @pip, random: FixedDice.new([ 1 ])) }
    assert_equal [ 0, 1 ], [ vassal.reload.size, vassal.refills_used ], "once, then it stays at 0d"
    @tibbs.push!("brawn", talent_key: "vassal", by: @pip)
    assert_equal 4, vassal.reload.size, "pushing yourself brings it back"
  end

  test "pools made when used: tick the use, cap how many, and go when they last out" do
    @tibbs.update!(path: "Psion", talent_keys: [ "echo" ])
    echo = @tibbs.make_talent_pool!("echo", "echo", by: @pip)
    assert_equal [ "Gibbletibble \"Tibbs\": Echo", 3, "power" ], [ echo.name, echo.size, echo.kind ]
    assert_equal 1, @tibbs.reload.uses_spent(use("echo"))
    assert_raises(ArgumentError) { @tibbs.make_talent_pool!("echo", "echo", by: @pip) }
    @tibbs.end_scene!
    assert Pool.exists?(echo.id), "an Echo lasts the session"
    @tibbs.start_session!
    refute Pool.exists?(echo.id)

    @tibbs.update!(path: "Artificer", talent_keys: [ "animate-objects" ])
    3.times { @tibbs.make_talent_pool!("animate-objects", "animated", by: @pip, name: "broom") }
    assert_equal "Gibbletibble \"Tibbs\": Animated (broom)", @tibbs.talent_pools.last.name
    refute @tibbs.can_make_pool?(Talent.find("animate-objects").makes.sole), "three at a time"
    assert_equal "Tibbs makes Animated (broom), a 2d power pool (Animate Objects).", @campaign.rolls.where(kind: "note").last.question
  end

  test "Soothsayer's Spirit pool rolls as bonus dice after anyone's roll" do
    bram = characters(:bram)
    @tibbs.update!(path: "Witch", talent_keys: [ "soothsayer" ])
    spirit = @tibbs.make_talent_pool!("soothsayer", "spirit", by: @pip, name: "the river")
    refute spirit.rolls_as_action?

    roll = bram.roll!("agility", by: identities(:gwen), random: FixedDice.new([ 2, 3 ]))
    assert_includes roll.follow_ups_for([ @tibbs ]).map { _3.id }, "soothsayer/spirit"
    roll.follow_up!(@tibbs, "soothsayer/spirit", by: @pip, random: FixedDice.new([ 6, 1, 4 ]))
    assert_equal [ "perfect", 2 ], [ roll.reload.outcome, spirit.reload.size ]
  end

  test "Augury: omens before each session, swapped into a roll and erased" do
    @tibbs.update!(path: "Druid", talent_keys: [ "augury" ])
    @tibbs.start_session!
    assert_equal 2, @tibbs.omens.size

    @tibbs.update!(talent_state: { "augury" => { "omens" => [ 6, 1 ] } })
    roll = @tibbs.roll!("agility", by: @pip, random: FixedDice.new([ 2, 3, 6 ]))
    roll.follow_up!(@tibbs, "augury/omen", by: @pip, die: 3, omen: 6)
    assert_equal [ [ 2, 6, 6 ], true ], [ roll.reload.dice, roll.critical ]
    assert_equal [ 1 ], @tibbs.reload.omens
    assert_raises(ArgumentError) { roll.follow_up!(@tibbs, "augury/omen", by: @pip, die: 2, omen: 6) }
  end

  test "herbs and quarries are this session's, by name" do
    @tibbs.update!(path: "Ranger", talent_keys: [ "herbalism" ])
    @tibbs.set_herbs!([ " moonwort ", "", "gallowsbane", "extra" ])
    assert_equal %w[ moonwort gallowsbane ], @tibbs.herbs

    @tibbs.designate_quarry!("The Grey Wolf", by: @pip)
    @tibbs.designate_quarry!("Mother Ash", by: @pip)
    assert_equal [ "The Grey Wolf", "Mother Ash" ], @tibbs.quarries
    assert_raises(ArgumentError) { @tibbs.designate_quarry!("A third", by: @pip) }

    @tibbs.start_session!
    assert_empty @tibbs.herbs + @tibbs.quarries
  end

  test "smite drops 1d from a task pool just rolled, 1-for-1" do
    @tibbs.update!(path: "Paladin", talent_keys: [])
    pool = @campaign.pools.create!(name: "Barroom brawl", kind: "task", starting_size: 4, size: 4)
    refute pool.smitable?, "only after it's rolled"
    pool.roll!(by: @pip, random: FixedDice.new([ 4, 5, 6, 1 ]))

    pool.smite!(character: @tibbs, by: @pip)
    pool.smite!(character: @tibbs, by: @pip)
    assert_equal [ 1, 2 ], [ pool.reload.size, @tibbs.reload.uses_spent(use("smite")) ]
    assert_equal "Gibbletibble \"Tibbs\" smites: 1d dropped. 1d left.", ApplicationController.helpers.pool_roll_summary(@campaign.rolls.last)
  end

  test "a Flesh Wound adds +1t to every roll, and isn't harm" do
    @tibbs.update!(path: "Berserker", talent_keys: [ "flesh-wounds" ])
    assert @tibbs.flesh_wounds?
    @tibbs.add_condition!(Character::Damage::FLESH_WOUND, lasts: "scene")
    assert_equal [ [ "flesh wound" ], [ "flesh wound" ] ], [ @tibbs.damage_reasons("wits"), @tibbs.damage_reasons("brawn") ]

    @tibbs.update!(path: "Paladin")
    assert_empty @tibbs.talent_bonuses_for("brawn"), "Oathsworn counts harm, not a Flesh Wound"
  end

  test "Animal Companion rolls its own dice: 3d for a trick" do
    @tibbs.update!(path: "Ranger", talent_keys: [ "animal-companion" ])
    roll = @tibbs.call_talent_roll!("animal-companion", 0, by: @pip)
    assert_equal [ "action", "trick", 3, "Animal Companion: One of its tricks" ], [ roll.kind, roll.stat, roll.dice.size, roll.question ]
    assert_match "3d Trick", ApplicationController.helpers.roll_setup(roll)
  end
end
