require "test_helper"

class CrucibleTest < ActiveSupport::TestCase
  test "every crucible has unique keys and full 6x6 tables" do
    assert_equal Crucible.all.map(&:key).uniq.size, Crucible.all.size

    Crucible.all.each do |crucible|
      assert crucible.tables.any?, "#{crucible.key} has no tables"
      assert_includes Crucible::GROUPS.keys, crucible.group

      crucible.tables.each do |table|
        assert_equal 6, table.rows.size, "#{crucible.key}/#{table.name} rows"
        table.rows.each { |row| assert_equal 6, row.size, "#{crucible.key}/#{table.name}: #{row.inspect}" }
        assert table.rows.flatten.all?(&:present?), "#{crucible.key}/#{table.name} has a blank cell"
      end
    end
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

  test "find raises not found for unknown keys" do
    assert_raises(ActiveRecord::RecordNotFound) { Crucible.find("nope") }
  end
end
