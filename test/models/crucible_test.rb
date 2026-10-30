require "test_helper"

class CrucibleTest < ActiveSupport::TestCase
  test "every crucible has unique keys and full tables of six rows" do
    assert_equal Crucible.all.map(&:key).uniq.size, Crucible.all.size

    Crucible.all.each do |crucible|
      assert crucible.tables.any?, "#{crucible.key} has no tables"
      assert_includes Crucible::GROUPS.keys, crucible.group

      crucible.tables.each do |table|
        if table.d8?
          assert_equal 2, table.width, "#{crucible.key}/#{table.name}: a d8 table is eight rows of two"
        else
          assert_equal 6, table.rows.size, "#{crucible.key}/#{table.name} rows"
        end
        assert_includes Crucible::WIDTHS, table.width, "#{crucible.key}/#{table.name}"
        table.rows.each { |row| assert_equal table.width, row.size, "#{crucible.key}/#{table.name}: #{row.inspect}" }
        assert_equal table.width, table.columns.size, "#{crucible.key}/#{table.name} columns" if table.columns
        assert table.rows.flatten.all?(&:present?), "#{crucible.key}/#{table.name} has a blank cell"
      end
    end
  end

  test "the crucibles from pages 79–86 and 141, checked against the book" do
    assert_equal [ "choke", "weed" ], Crucible.find("herbalism").tables.then { [ _1.first.cell(1, 1), _1.last.cell(6, 6) ] }
    assert_match "Juniper Bloom", Crucible.find("herbalism").credit
    assert_equal [ "squat", "float" ], Crucible.find("vassal").tables.then { [ _1.first.cell(1, 1), _1.last.cell(6, 2) ] }
    assert_equal [ 3, "avenger" ], Crucible.find("legend").tables.last.then { [ _1.width, _1.cell(6, 3) ] }
    assert_equal %w[ well hope buzz surge turn smoke drift morn ], %w[ spring summer fall winter ].flat_map { |key| Crucible.find(key).tables.first(2).map { _1.cell(6, 1) } }
  end

  test "the seasons' atmospherics, checked against the Community Edition" do
    atmospherics = %w[ spring summer fall winter ].map { |key| Crucible.find(key).tables.last }
    assert_equal [ "Atmospherics" ], atmospherics.map(&:name).uniq
    assert_equal [ "frost melts", "clear skies", "endless downpours", "dying fungi", "drifting embers", "pollen fires", "whispering winds", "frozen silence" ],
      atmospherics.flat_map { [ _1.cell(1, 1), _1.cell(6, 2) ] }
  end

  test "the Community Edition's crucibles for artificers, paladins, treasure and potions" do
    assert_equal [ "alche-", "-knob" ], Crucible.find("magitechnobabble").tables.then { [ _1.first.cell(1, 1), _1.last.cell(6, 6) ] }
    assert_equal [ "honor—valor", "my trait, …", "my lack of…" ], Crucible.find("tenet_builder").tables.sole.then { [ _1.cell(1, 1), _1.cell(2, 3), _1.cell(6, 3) ] }
    assert_equal [ "favor", "blessing" ], Crucible.find("treasure").tables.sole.then { [ _1.cell(1, 1), _1.cell(6, 3) ] }
    potion = Crucible.find("potion").tables
    assert_equal [ "wither, fungus, servant", "pierce, bone, mask", "shock, terror, heart" ], potion.first.then { [ _1.cell(1, 1), _1.cell(1, 6), _1.cell(6, 6) ] }
    assert_equal %w[ foggy tapered flask glass colorful strange mist oil ], potion.drop(1).flat_map { [ _1.cell(1, 1), _1.cell(6, 1) ] }
    assert_equal "magitechnobabble", Talent.find("infusion").crucible
    assert_equal "tenet_builder", Talent.find("oathsworn").crucible
  end

  test "past entanglements: How, then Who" do
    assert_equal %w[ How Who ], Crucible.find("entanglements").tables.map(&:name)
  end

  test "every talent's crucible exists" do
    Talent.all.select(&:crucible).each { assert Crucible.find(_1.crucible), _1.key }
  end

  test "the GM crucible reads 3 and 1 both ways, as in the book (pg. 94)" do
    quality = Crucible.find("gm").tables.first

    assert_equal "broken", quality.cell(3, 1)
    assert_equal "precarious", quality.cell(1, 3)
  end

  test "multi-word cells stay whole" do
    assert_equal "fortune teller", Crucible.find("buildings").tables.last.cell(6, 2)
    assert_equal "over the hill", Crucible.find("features").tables.last.cell(3, 5)
    assert_equal %w[Civilization Social History Nature Mysticism Practical], Crucible.find("wises").tables.first.columns
  end

  test "the spell, words of power and patron crucibles, checked against the book (pg. 83, 85, 87)" do
    spell = Crucible.find("spell")
    assert_equal %w[ Style Essence Form ], spell.tables.map(&:name)
    assert_equal [ "binding", "whispering", "oil", "growth", "beacon", "field" ], spell.tables.flat_map { [ _1.cell(1, 1), _1.cell(6, 6) ] }
    assert_equal "false", spell.tables.first.cell(5, 3), "quoted, so YAML doesn't make it a boolean"

    words = Crucible.find("words_of_power").tables
    assert_equal [ "spirit", "ice", "read", "poison" ], words.flat_map { [ _1.cell(1, 1), _1.cell(6, 6) ] }

    patron = Crucible.find("patron").tables
    assert_equal %w[ Nature Desires ], patron.map(&:name)
    assert_equal "dead god", patron.first.cell(4, 1)
    assert_equal "entropy", patron.last.cell(6, 6)
  end

  test "a narrower table's columns name the second die's faces" do
    assert_equal [ "1–3", "4–6" ], Crucible.find("vassal").tables.first.then { |table| 2.times.map { table.column_dice(_1) } }
    assert_equal [ "1–2", "3–4", "5–6" ], Crucible.find("legend").tables.first.then { |table| 3.times.map { table.column_dice(_1) } }
    assert_nil Crucible.find("gm").tables.first.column_dice(0)
    assert_nil Crucible.find("eldritch_mutations").tables.first.column_dice(0)
    assert_nil Crucible.find("vassal").tables.first.column_label(0), "Build, under Build"
    assert_equal "Playful", Crucible.find("legend").tables.first.column_label(0)
  end

  test "the solo rules' consequences are d8 tables, checked against the Community Edition (pg. 194)" do
    low, high = %w[ solo_low_stakes solo_high_stakes ].map { Crucible.find(_1).tables.sole }
    assert [ low, high ].all?(&:d8?)
    assert_equal [ "set dressing", "harm" ], [ low.cell(1, 1), low.cell(8, 2) ]
    assert_equal [ "vex", "harm & condition" ], [ high.cell(1, 1), high.cell(8, 2) ]
    assert_not low.headed?
    assert_nil low.column_dice(0)
    assert_match "@slander.x", Crucible.find("solo_low_stakes").credit
  end

  test "find raises not found for unknown keys" do
    assert_raises(ActiveRecord::RecordNotFound) { Crucible.find("nope") }
  end

  test "the monster pages' d6 tables and the vassal's aspects, checked against the book (pg. 79, 146–172)" do
    monsters = Crucible.all.select { _1.group == "monsters" }
    assert_equal 59, monsters.size, "54 d6 lists and 5 word grids"
    assert_equal 54, monsters.count { _1.tables.one? && _1.tables.sole.width == 1 }
    assert_equal "It's lonely, the last of its kind.", Crucible.find("monster_cyclopean_curses").tables.sole.cell(6, 1)
    assert_equal "Lies, broke a promise made in desperation.", Crucible.find("monster_curse_origins").tables.sole.cell(2, 1)
    assert_equal [ "dragon: Eldritch Growth", "tentacles: Fearsome" ], Crucible.find("vassal_aspects").tables.sole.then { [ _1.cell(1, 1), _1.cell(6, 2) ] }
    assert_equal "vassal_aspects", Talent.find("vassal").choice("aspects").crucible
  end

  test "every cell is text, not a word YAML reads as true, false or a number" do
    YAML.load_file(Rails.root.join("config/crucibles.yml")).each do |crucible|
      crucible["tables"].each { |table| table["rows"].flatten.each { assert_kind_of String, _1, crucible["key"] } }
    end
  end

  test "the monster pages' word grids roll several lists together (pg. 159–170)" do
    assert_equal [ "charred stone bastion", "sulfuric cave system" ], Crucible.find("monster_seat_of_power").tables.then { [ _1.first.cell(1, 1), _1.last.cell(6, 1) ] }
    assert_equal [ 3, "mist" ], Crucible.find("monster_types_of_mephit").tables.sole.then { [ _1.width, _1.cell(6, 3) ] }
    assert_equal "It grows taller, then vanishes.", Crucible.find("monster_riddle").tables.first.cell(2, 1)
    assert_equal %w[ relic promise obsession ], Crucible.find("monster_unfinished_business").tables.map { _1.cell(6, 1) }
  end
end
