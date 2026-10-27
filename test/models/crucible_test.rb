require "test_helper"

class CrucibleTest < ActiveSupport::TestCase
  test "every crucible has unique keys and full tables of six rows" do
    assert_equal Crucible.all.map(&:key).uniq.size, Crucible.all.size

    Crucible.all.each do |crucible|
      assert crucible.tables.any?, "#{crucible.key} has no tables"
      assert_includes Crucible::GROUPS.keys, crucible.group

      crucible.tables.each do |table|
        assert_equal 6, table.rows.size, "#{crucible.key}/#{table.name} rows"
        assert_includes Crucible::WIDTHS, table.width, "#{crucible.key}/#{table.name}"
        table.rows.each { |row| assert_equal table.width, row.size, "#{crucible.key}/#{table.name}: #{row.inspect}" }
        assert_equal table.width, table.columns.size, "#{crucible.key}/#{table.name} columns" if table.columns
        assert table.rows.flatten.all?(&:present?), "#{crucible.key}/#{table.name} has a blank cell"
      end
    end
  end

  test "the crucibles from pages 78–85 and 140, checked against the book" do
    assert_equal [ "choke", "weed" ], Crucible.find("herbalism").tables.then { [ _1.first.cell(1, 1), _1.last.cell(6, 6) ] }
    assert_match "Juniper Bloom", Crucible.find("herbalism").credit
    assert_equal [ "squat", "float" ], Crucible.find("vassal").tables.then { [ _1.first.cell(1, 1), _1.last.cell(6, 2) ] }
    assert_equal [ 3, "avenger" ], Crucible.find("legend").tables.last.then { [ _1.width, _1.cell(6, 3) ] }
    assert_equal %w[ well hope buzz surge turn smoke drift morn ], %w[ spring summer fall winter ].flat_map { |key| Crucible.find(key).tables.map { _1.cell(6, 1) } }
  end

  test "every talent's crucible exists" do
    Talent.all.select(&:crucible).each { assert Crucible.find(_1.crucible), _1.key }
  end

  test "the GM crucible reads 3 and 1 both ways, as in the book (pg. 93)" do
    quality = Crucible.find("gm").tables.first

    assert_equal "broken", quality.cell(3, 1)
    assert_equal "precarious", quality.cell(1, 3)
  end

  test "multi-word cells stay whole" do
    assert_equal "fortune teller", Crucible.find("buildings").tables.last.cell(6, 2)
    assert_equal "over the hill", Crucible.find("features").tables.last.cell(3, 5)
    assert_equal %w[Civil Social Historical Natural Mystical Practical], Crucible.find("wises").tables.first.columns
  end

  test "the spell, words of power and patron crucibles, checked against the book (pg. 82, 84, 86)" do
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

  test "find raises not found for unknown keys" do
    assert_raises(ActiveRecord::RecordNotFound) { Crucible.find("nope") }
  end
end
