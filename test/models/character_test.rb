require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  setup { @tibbs = characters(:tibbs) }

  test "starting stats add up to 8, 1-3 each" do
    character = identities(:pip).characters.new(name: "Ash", path: "Fighter", brawn: 3, agility: 3, wits: 3, presence: 1)
    assert_not character.valid?
    assert_match(/add up to 8/, character.errors.full_messages.to_sentence)

    character.assign_attributes(brawn: 3, agility: 2, wits: 2, presence: 1)
    assert character.valid?

    character.brawn = 4
    assert_not character.valid?
  end

  test "path must be one of the book's paths, and gives its core talent" do
    assert_equal "Expertise", @tibbs.core_talent
    @tibbs.path = "Necromancer"
    assert_not @tibbs.valid?
  end

  test "damage adds thorns to the right stats" do
    assert_equal 0, @tibbs.damage_thorns(:agility)

    @tibbs.update!(marked_agility: true, bloodied: true)
    assert_equal 2, @tibbs.damage_thorns(:agility)
    assert_equal 1, @tibbs.damage_thorns(:brawn)
    assert_equal 0, @tibbs.damage_thorns(:wits)

    @tibbs.update!(rattled: true, desperate: true)
    assert_equal 2, @tibbs.damage_thorns(:wits)
    assert_equal %w[marked bloodied desperate], @tibbs.damage_reasons(:agility)
  end

  test "rolling a marked stat adds its thorn, then clears the mark" do
    @tibbs.update!(marked_agility: true)

    roll = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 5, 2, 1, 7 ]))
    assert_equal [ 5, 2, 1 ], roll.dice
    assert_equal [ 7 ], roll.thorns
    assert_equal "grim", roll.outcome
    assert_equal [ "marked" ], roll.damage_reasons
    assert_not @tibbs.reload.marked_agility?
  end

  test "each spark spent adds 1d" do
    roll = @tibbs.roll!("wits", by: identities(:pip), spend_spark: 1, help: 1, thorns: 2, random: FixedDice.new([ 1, 2, 4, 6, 3, 3 ]))

    assert_equal 4, roll.dice.size, "2 Wits + 1 spark + 1 help"
    assert_equal 2, roll.thorns.size
    assert_equal 1, roll.spark_spent
    assert_equal "perfect", roll.outcome
    assert_equal 0, @tibbs.reload.spark
  end

  test "an assist rolls its own die, which counts toward the result" do
    roll = @tibbs.roll!("wits", by: identities(:pip), assists: [ characters(:bram) ], random: FixedDice.new([ 2, 3, 6 ]))

    assert_equal [ 2, 3 ], roll.dice
    assert_equal [ { "character_id" => characters(:bram).id, "name" => "Bram", "die" => 6 } ], roll.assists
    assert_equal "perfect", roll.outcome, "Bram's 6 sets the result"
    assert_equal [ 2, 3, 6 ], roll.all_dice
  end

  test "an assist's 6 can make a critical" do
    roll = @tibbs.roll!("wits", by: identities(:pip), assists: [ characters(:bram) ], random: FixedDice.new([ 6, 1, 6 ]))
    assert roll.critical?
  end

  test "only other characters seated alongside can assist" do
    [ [ @tibbs ], [ characters(:loner) ], [ characters(:bram), characters(:bram) ] ].each do |assists|
      assert_raises(ArgumentError) { @tibbs.roll!("wits", by: identities(:pip), assists: assists) }
    end
    assert_raises(ArgumentError) { characters(:loner).roll!("wits", by: identities(:stranger), assists: [ characters(:bram) ]) }
  end

  test "a disaster gives spark, up to 2" do
    roll = @tibbs.roll!("brawn", by: identities(:pip), thorns: 1, random: FixedDice.new([ 2, 8 ]))
    assert_equal "disaster", roll.outcome
    assert roll.spark_gained?
    assert_equal 2, @tibbs.reload.spark

    roll = @tibbs.roll!("brawn", by: identities(:pip), thorns: 1, random: FixedDice.new([ 2, 8 ]))
    assert_not roll.spark_gained?
    assert_equal 2, @tibbs.reload.spark
  end

  test "spending spark can set up the disaster that pays it back" do
    roll = @tibbs.roll!("brawn", by: identities(:pip), spend_spark: 1, thorns: 1, random: FixedDice.new([ 1, 3, 7 ]))

    assert_equal "disaster", roll.outcome
    assert_equal 1, @tibbs.reload.spark, "spent 1, then took 1"
  end

  test "a critical where nothing fits gives spark, once, on the latest roll" do
    critical = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 1 ]))
    assert @tibbs.can_take_spark_for?(critical)

    @tibbs.take_spark_for_critical!(critical)
    assert_equal 2, @tibbs.reload.spark
    assert critical.reload.spark_gained?
    assert_raises(ArgumentError) { @tibbs.take_spark_for_critical!(critical) }
  end

  test "no critical spark for a plain perfect, an older roll, or at 2 spark" do
    perfect = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 5, 1 ]))
    assert_not @tibbs.can_take_spark_for?(perfect)

    older = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 1 ]))
    @tibbs.roll!("wits", by: identities(:pip))
    assert_not @tibbs.can_take_spark_for?(older)

    @tibbs.update!(spark: 2)
    latest = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 6, 6, 1 ]))
    assert_not @tibbs.can_take_spark_for?(latest)
  end

  test "a seated character's roll goes in the campaign log; an unseated one's doesn't" do
    roll = @tibbs.roll!("agility", by: identities(:pip))
    assert_equal campaigns(:bramblewood), roll.campaign
    assert_equal @tibbs.name, roll.name

    assert_nil characters(:loner).roll!("agility", by: identities(:stranger)).campaign
  end

  test "rolls stay within the rules" do
    assert_raises(ArgumentError) { @tibbs.roll!("luck", by: identities(:pip)) }
    assert_raises(ArgumentError) { @tibbs.roll!("wits", by: identities(:pip), spend_spark: 2) }
    assert_raises(ArgumentError) { @tibbs.roll!("wits", by: identities(:pip), mode: "story") }
    assert_raises(ArgumentError) { @tibbs.roll!("wits", by: identities(:pip), thorns: 9) }
    assert_equal 1, @tibbs.reload.spark
  end

  test "XP fills level + 1 boxes, then levels up" do
    assert_equal 2, @tibbs.xp_to_next_level

    assert_not @tibbs.gain_xp!
    assert @tibbs.gain_xp!
    assert_equal [ 2, 0 ], [ @tibbs.level, @tibbs.xp ]

    @tibbs.update!(level: 7)
    assert_not @tibbs.gain_xp!
    assert_equal 0, @tibbs.xp
  end

  test "list fields are cleaned and capped" do
    @tibbs.update!(
      traits: [ " brave ", "", "rash", "kind" ],
      features: [ "a", "b", "c", "d" ],
      backgrounds: { "0" => { "name" => "Sage", "wises" => [ "philosophy", "", " lore " ] }, "1" => { "name" => "", "wises" => [ "", "", "" ] } },
      bonds: { "0" => { "to" => "Lillylux", "bond" => "lowkey affection" }, "1" => { "to" => "", "bond" => "" } }
    )

    assert_equal %w[brave rash], @tibbs.traits
    assert_equal %w[a b c], @tibbs.features
    assert_equal [ { "name" => "Sage", "wises" => [ "philosophy", "lore" ] } ], @tibbs.backgrounds
    assert_equal [ { "to" => "Lillylux", "bond" => "lowkey affection" } ], @tibbs.bonds
  end

  test "one bond toward each other character at the table, as many as there are" do
    bram = characters(:bram)
    moss = identities(:gwen).characters.create!(name: "Moss", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: campaigns(:bramblewood))
    assert_equal [ bram, moss ], @tibbs.bond_party

    @tibbs.update!(bonds: {
      "0" => { "character_id" => bram.id.to_s, "to" => "Bram", "bond" => "tense rivalry" },
      "1" => { "character_id" => moss.id.to_s, "to" => "Moss", "bond" => "" },
      "2" => { "character_id" => bram.id.to_s, "to" => "Bram", "bond" => "deep respect" },
      "3" => { "to" => "Lillylux", "bond" => "lowkey affection" },
      "4" => { "to" => "lillylux", "bond" => "playful envy" }
    })

    assert_equal [ { "to" => "Bram", "bond" => "tense rivalry", "character_id" => bram.id }, { "to" => "Lillylux", "bond" => "lowkey affection" } ], @tibbs.bonds,
      "one per character, and a blank row for someone at the table is dropped"
    assert_equal "tense rivalry", @tibbs.bond_for(bram)["bond"]
    assert_nil @tibbs.bond_for(moss)
    assert_equal [ { "to" => "Lillylux", "bond" => "lowkey affection" } ], @tibbs.bonds_beyond(@tibbs.bond_party)
  end

  test "a bond written by name before bonds knew ids still finds its character" do
    @tibbs.update!(bonds: [ { "to" => "bram", "bond" => "growing kinship" } ])
    assert_equal "growing kinship", @tibbs.bond_for(characters(:bram))["bond"]
    assert_empty @tibbs.bonds_beyond([ characters(:bram) ])
  end

  test "can only sit in your own campaigns" do
    characters(:loner).campaign = campaigns(:bramblewood)
    assert_not characters(:loner).valid?
  end

  test "who can see a character" do
    assert_includes Character.visible_to(identities(:gwen)), @tibbs, "the GM sees characters at their table"
    assert_not_includes Character.visible_to(identities(:stranger)), @tibbs
    assert_includes Character.visible_to(identities(:stranger)), characters(:loner)
  end

  test "leaving a campaign takes your characters with you" do
    memberships(:pip_player).destroy
    assert_nil @tibbs.reload.campaign
  end

  test "conditions" do
    @tibbs.add_condition!("4d poisoned")
    @tibbs.add_condition!("broken arm")
    @tibbs.remove_condition!(0)
    assert_equal [ { "name" => "broken arm", "lasts" => nil } ], @tibbs.reload.conditions

    @tibbs.add_condition!("twisted ankle", lasts: "scene")
    @tibbs.add_condition!("drunk", lasts: "forever")
    assert_equal [ [ 1, { "name" => "twisted ankle", "lasts" => "scene" } ] ], @tibbs.scene_conditions
    assert_nil @tibbs.conditions.last["lasts"], "only scene-length conditions are tracked"

    @tibbs.update!(conditions: [ "a plain string", { name: "  " } ])
    assert_equal [ { "name" => "a plain string", "lasts" => nil } ], @tibbs.reload.conditions
  end
end

class CharacterTalentsTest < ActiveSupport::TestCase
  setup { @tibbs = characters(:tibbs) }

  test "core talent comes from the path, chosen talents from the catalog" do
    assert_equal "Expertise", @tibbs.core_talent_entry.name
    assert_equal [ "According to Plan" ], @tibbs.chosen_talents.map(&:name)
    assert_equal 0, @tibbs.talents_to_choose

    @tibbs.update!(level: 2)
    assert_equal 1, @tibbs.talents_to_choose
  end

  test "add and remove talents" do
    @tibbs.update!(level: 2)
    @tibbs.add_talent!("lucky")
    @tibbs.add_talent!("lucky")
    assert_equal %w[according-to-plan lucky], @tibbs.reload.talent_keys

    @tibbs.remove_talent!("lucky")
    assert_equal %w[according-to-plan], @tibbs.reload.talent_keys
  end

  test "one chosen talent per level, from any path" do
    assert @tibbs.talents_full?
    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.add_talent!("lucky") }
    assert_equal %w[according-to-plan], @tibbs.reload.talent_keys

    @tibbs.update!(level: 2)
    @tibbs.add_talent!("bulwark")
    assert @tibbs.reload.talents_full?

    @tibbs.level = 1
    assert_not @tibbs.valid?, "can't drop below the talents taken"
    assert_match "remove one first", @tibbs.errors.full_messages.to_sentence
  end

  test "a sheet already over the limit still saves other changes, and says so" do
    @tibbs.update_columns(talent_keys: %w[according-to-plan lucky])
    assert_equal 1, @tibbs.extra_talents
    @tibbs.update!(spark: 2)

    @tibbs.remove_talent!("lucky")
    assert_equal 0, @tibbs.reload.extra_talents
  end

    test "can't take a core talent, an unknown one, or one prohibited for the path" do
    @tibbs.talent_keys = [ "sorcery" ]
    assert_not @tibbs.valid?

    @tibbs.talent_keys = [ "not-a-talent" ]
    assert_not @tibbs.valid?

    @tibbs.path = "Sorcerer"
    @tibbs.talent_keys = [ "eldritch-affinity" ]
    assert_not @tibbs.valid?
  end

  test "bonds are cut to a sensible length" do
    character = characters(:tibbs)
    character.bonds = [ { "to" => "M" * 100, "bond" => "B" * 100 } ]
    assert_equal [ Character::BOND_LIMIT, Character::BOND_LIMIT ], character.bonds.first.values_at("to", "bond").map(&:length)
  end

  test "each detail word is cut to a sensible length" do
    long = "x" * 100
    character = characters(:tibbs)
    character.assign_attributes(traits: [ long ], features: [ long ], not_trait: long, weapons: long,
      backgrounds: [ { "name" => long, "wises" => [ long ] } ])
    limit = Character::WORD_LIMIT
    assert_equal [ limit ] * 6, [ character.traits.first, character.features.first, character.not_trait, character.weapons,
      character.backgrounds.first["name"], character.backgrounds.first["wises"].first ].map(&:length)
  end
end
