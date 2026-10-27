require "test_helper"

# Preview 6's Adventurer path, Oathbreaker and the level 0 and retired-talent
# rules (docs/design/p6-update, Phases 4 and 5).
class CharacterP6PathsTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs)
    @pip = identities(:pip)
  end

  test "the Adventurer's Talented: no path core, 2 extra talents, +1 at levels 3 and 6" do
    @tibbs.update!(path: "Adventurer", talent_keys: [])
    assert_equal "talented", @tibbs.core_talent_entry.key
    assert_equal [ 3, 6, 10 ], [ 1, 3, 6 ].map { @tibbs.level = _1; @tibbs.expected_talent_count }

    @tibbs.level = 1
    @tibbs.update!(talent_keys: %w[ lucky lurker weasel ])
    assert @tibbs.talents_full?
    @tibbs.talent_keys += %w[ poisoner ]
    assert_not @tibbs.valid?
  end

  test "Oathbreaker: Talented replaces Oathsworn; redemption, once, keeps one talent" do
    @tibbs.update!(path: "Paladin", level: 2, talent_keys: %w[ aegis lucky ])
    assert_equal "oathsworn", @tibbs.core_talent_entry.key

    assert_difference -> { Roll.where(kind: "note").count } do
      @tibbs.break_oath!(by: @pip)
    end
    assert_equal [ "talented", 4 ], [ @tibbs.core_talent_entry.key, @tibbs.expected_talent_count ]
    @tibbs.update!(talent_keys: %w[ aegis lucky lurker weasel ])

    @tibbs.redeem_oath!(by: @pip)
    assert_equal [ "oathsworn", 3 ], [ @tibbs.core_talent_entry.key, @tibbs.expected_talent_count ]
    assert_equal 1, @tibbs.extra_talents, "the sheet asks for one to go"
    assert_match "is redeemed", Roll.where(kind: "note").last.question

    @tibbs.break_oath!(by: @pip)
    assert_raises(ArgumentError) { @tibbs.redeem_oath!(by: @pip) } # only once
    assert_raises(ArgumentError) { characters(:bram).break_oath!(by: identities(:gwen)) } # a Fighter has no oath
  end

  test "level 0: 3 stat points and no core talent, then the core and the last point at level 1" do
    kit = @pip.characters.create!(name: "Kit", path: "Rogue", level_zero: true, brawn: 1, agility: 2, wits: 2, presence: 2)
    assert_equal [ 0, nil, 1 ], [ kit.level, kit.core_talent_entry, kit.expected_talent_count ]
    assert_not @pip.characters.new(name: "Kat", path: "Rogue", level_zero: true, brawn: 1, agility: 3, wits: 2, presence: 2).valid?, "4 points at level 0"
    assert_not kit.stat_point_due?

    assert kit.gain_xp!, "1 XP reaches level 1"
    assert_equal "expertise", kit.core_talent_entry.key
    assert kit.stat_point_due?
    kit.add_stat_point!("wits", by: @pip)
    assert_equal 3, kit.reload.wits
    assert_not kit.stat_point_due?
    assert_raises(ArgumentError) { kit.add_stat_point!("brawn", by: @pip) }

    @tibbs.level = 0
    assert_not @tibbs.valid?, "only a character who started at level 0 can be level 0"
  end

  test "Flurry is retired: out of the catalog and no new pick, but a sheet that has it keeps it" do
    flurry = Talent.find("flurry")
    assert flurry.retired?
    assert_not_includes Talent.groups.find { _1.key == "legacy" }.talents, flurry
    assert_not_includes Talent.choosable_for("Monk"), flurry
    assert_includes Talent.groups.find { _1.key == "legacy" }.talents.map(&:key), "prepared-spell"

    @tibbs.talent_keys = %w[ flurry ]
    assert_not @tibbs.valid?

    @tibbs.update_columns(talent_keys: %w[ flurry ])
    assert @tibbs.reload.valid?
  end

  test "core talents keep their notes now: the Vassal's spark and thread are shared" do
    assert_match "Your spark and thread are shared", Talent.find("vassal").note
  end
end
