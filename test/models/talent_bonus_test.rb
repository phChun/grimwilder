require "test_helper"

# Talent::Bonus (config/talents.yml `bonuses:`) and what they add to a roll
# from the sheet (Character::TalentBonuses, Character#roll!).
class TalentBonusTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs) # a Rogue: Expertise is the core talent
    @pip = identities(:pip)
  end

  test "every bonus is well formed: its rolls, stats, choice and use are real" do
    bonused = Talent.all.select { _1.bonuses.any? }
    assert bonused.size >= 25

    bonused.each do |talent|
      talent.bonuses.each do |bonus|
        assert bonus.label.present?, bonus.id
        assert bonus.dice.in?(0..2), bonus.id
        assert (bonus.on - Talent::Bonus::ROLLS - Talent::Bonus::GROUP_ROLLS).empty?, bonus.id
        assert bonus.stats.empty? && !bonus.harm && !bonus.per_mark && !bonus.ignore, bonus.id if (bonus.on & Talent::Bonus::ROLLS).empty?
        assert (bonus.stats - Grimwild::STATS).empty?, bonus.id
        assert_includes Talent::Bonus::IGNORES, bonus.ignore, bonus.id if bonus.ignore
        assert talent.choice(bonus.choice), bonus.id if bonus.choice
        assert_includes talent.uses.select(&:counter?).map(&:id), bonus.use_id, bonus.id if bonus.use
      end
      assert_equal talent.bonuses.map(&:key).uniq.size, talent.bonuses.size, talent.key
    end
  end

  test "a ticked bonus adds its die and is named on the roll" do
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel stealth lying ])
    talent, bonus = @tibbs.talent_bonuses_for("agility").sole
    assert_equal [ "Expertise", "expertise/skill" ], [ talent.name, bonus.id ]

    roll = @tibbs.roll!("agility", by: @pip, bonuses: [ "expertise/skill" ], random: FixedDice.new([ 2, 3, 1, 5 ]))
    assert_equal 4, roll.dice.size, "3 Agility + 1 from Expertise"
    assert_equal "messy", roll.outcome
    assert_equal [ { "id" => "expertise/skill", "name" => "Expertise", "dice" => 1, "ignored" => 0 } ], roll.talent_bonuses

    plain = @tibbs.roll!("agility", by: @pip, random: FixedDice.new([ 2, 3, 1 ]))
    assert_equal [], plain.talent_bonuses
  end

  test "a re-skinned talent's tick and log line wear its own name" do
    @tibbs.reskin_talent!("expertise", "name" => "Street Smarts")
    roll = @tibbs.roll!("wits", by: @pip, bonuses: [ "expertise/skill" ], random: FixedDice.new([ 1, 1, 1 ]))
    assert_equal "Street Smarts", roll.talent_bonuses.sole["name"]
  end

  test "only bonuses the stat offers, and a defense-only one counts only on a defense" do
    error = assert_raises(ArgumentError) { @tibbs.roll!("agility", by: @pip, bonuses: [ "aegis/aegis" ]) }
    assert_match "no talent bonus", error.message

    @tibbs.update!(talent_keys: [ "aegis" ])
    action = @tibbs.roll!("brawn", by: @pip, bonuses: [ "aegis/aegis" ], random: FixedDice.new([ 4 ]))
    assert_equal [ 1, [] ], [ action.dice.size, action.talent_bonuses ]
    defense = @tibbs.roll!("brawn", by: @pip, mode: "defense", bonuses: [ "aegis/aegis" ], random: FixedDice.new([ 4, 6 ]))
    assert_equal [ 2, "perfect" ], [ defense.dice.size, defense.outcome ]
  end

  test "a bonus that spends a use ticks it, and none left refuses" do
    @tibbs.update!(path: "Monk", talent_keys: [])
    flow = @tibbs.use_counters.find { _1.key == "flow" }
    @tibbs.update!(talent_uses: { flow.id => 3 })

    roll = @tibbs.roll!("agility", by: @pip, bonuses: [ "discipline/flow" ], random: FixedDice.new([ 2, 2, 2 ]))
    assert_equal 3, roll.dice.size, "flow adds no dice"
    assert_equal 4, @tibbs.reload.uses_spent(flow)
    refute @tibbs.bonus_ready?(@tibbs.talent_bonuses_for("agility").sole.last)

    error = assert_raises(ArgumentError) { @tibbs.roll!("agility", by: @pip, bonuses: [ "discipline/flow" ]) }
    assert_match "No flow left", error.message
  end

  test "Frenzy: +1d for each mark, and marks and harm add no thorns" do
    @tibbs.update!(path: "Berserker", talent_keys: [], marked_agility: true, marked_wits: true, bloodied: true)
    roll = @tibbs.roll!("agility", by: @pip, thorns: 1, bonuses: [ "frenzy/frenzy" ], random: FixedDice.new([ 2, 2, 2, 2, 3, 8 ]))
    assert_equal [ 5, 1, [] ], [ roll.dice.size, roll.thorns.size, roll.damage_reasons ], "3 + 2 marks; only the situational thorn"
    assert_equal 2, roll.talent_bonuses.sole["ignored"]
    refute @tibbs.reload.marked_agility?, "the mark still clears"
  end

  test "automatic bonuses: Oathsworn's +1d for harm, Lightning Reflexes on an Agility defense" do
    @tibbs.update!(path: "Paladin", talent_keys: [ "lightning-reflexes" ], bloodied: true)
    assert_equal [ "oathsworn/tenets", "lightning-reflexes/reflexes" ], @tibbs.talent_bonuses_for("agility").map { _2.id }
    assert_equal [ "oathsworn/tenets" ], @tibbs.talent_bonuses_for("brawn").map { _2.id }, "Lightning Reflexes is Agility only"
    assert_empty @tibbs.talent_bonuses_for("wits"), "Oathsworn only where harm adds a thorn"

    roll = @tibbs.roll!("agility", by: @pip, mode: "defense", thorns: 2, random: FixedDice.new([ 1, 1, 1, 1, 7 ]))
    assert_equal [ 4, 1 ], [ roll.dice.size, roll.thorns.size ], "+1d for Bloodied; the 2 situational thorns are left out"
    assert_equal [ 1, 2 ], roll.talent_bonuses.map { _1["dice"] + _1["ignored"] }
  end

  test "at a roll call: the player ticks a story roll's talent, and an automatic one counts even when the GM rolls" do
    campaign = campaigns(:bramblewood)
    @tibbs.update!(path: "Bard", talent_keys: [ "bardic-lore" ])
    call = RollCall.story!(campaign: campaign, by: identities(:gwen), character: @tibbs, odds: 2)
    assert_equal [ "bardic-lore/lore" ], @tibbs.talent_bonuses_for_call("story").map { _2.id }

    error = assert_raises(ArgumentError) { call.roll!(@tibbs, by: identities(:gwen), bonuses: [ "bardic-lore/lore" ]) }
    assert_match "Only Gibbletibble", error.message
    call.roll!(@tibbs, by: @pip, bonuses: [ "bardic-lore/lore" ], random: FixedDice.new([ 1, 2, 6 ]))
    roll = call.reload.roll
    assert_equal [ [ 1, 2, 6 ], "perfect", "Bardic Lore" ], [ roll.dice, roll.outcome, roll.talent_bonuses.sole["name"] ]
    assert_equal 2, roll.stat_dice, "the odds stay the odds"

    @tibbs.update!(talent_keys: [ "jack-of-all-trades" ])
    montage = RollCall.montage!(campaign: campaign, by: identities(:gwen), characters: [ @tibbs, characters(:bram) ])
    montage.roll_everyone!(by: identities(:gwen), random: FixedDice.new([ 1, 1, 6, 2, 2 ]))
    side = montage.reload.roll.sides.first
    assert_equal [ [ 1, 1, 6 ], "Jack of All Trades" ], [ side["dice"], side["talent_bonuses"].sole["name"] ]
    assert_equal "perfect", montage.roll.outcome
  end
end
