require "test_helper"

# Legacy talents (pg. 178–179): older versions a GM may allow.
class LegacyTalentTest < ActiveSupport::TestCase
  test "legacy path talents can be chosen; legacy cores replace the path's core instead" do
    legacy = Talent.groups.find { _1.key == "legacy" }
    assert_equal 13, legacy.talents.size
    choosable = Talent.choosable_for("Rogue").map(&:key)
    assert_includes choosable, "trap-sense"
    refute_includes choosable, "bardsong-legacy"

    tibbs = characters(:tibbs)
    tibbs.update!(path: "Bard", talent_keys: [])
    assert_equal "inspiration", tibbs.core_talent_entry.key
    tibbs.update!(legacy_core: true)
    assert_equal "bardsong-legacy", tibbs.core_talent_entry.key
    assert_equal [ "bardsongs", "melodies" ], tibbs.use_counters.map(&:key)

    tibbs.update!(path: "Rogue")
    assert_equal "expertise", tibbs.core_talent_entry.key, "no legacy Rogue core: the path's own"
  end
end
