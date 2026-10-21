require "test_helper"

class TalentTest < ActiveSupport::TestCase
  test "17 paths, each with a core talent and 7 path talents, plus background talents" do
    paths = Talent.groups.select(&:path?)
    assert_equal Grimwild.paths.keys.sort, paths.map(&:name).sort

    paths.each do |group|
      assert_equal 1, group.talents.count(&:core?), "#{group.name} core"
      assert_equal 7, group.talents.reject(&:core?).size, "#{group.name} path talents"
      assert_equal Grimwild.core_talent(group.name), Talent.core_for(group.name).name
    end

    assert Talent.groups.find { |group| group.key == "backgrounds" }.talents.any?
  end

  test "keys are unique and every talent has text" do
    assert_equal Talent.all.size, Talent.all.map(&:key).uniq.size
    Talent.all.each { |talent| assert talent.text.present?, "#{talent.key} has no text" }
  end

  test "every talent has a one-line summary for the sheet" do
    Talent.all.each do |talent|
      assert talent.summary.present?, "#{talent.key} has no summary"
      assert_operator talent.summary.length, :<=, 100, "#{talent.key}'s summary is too long"
      assert_no_match(/\n/, talent.summary, talent.key)
    end
  end

  test "prohibited talents can't be chosen by that path" do
    affinity = Talent.find("eldritch-affinity")

    assert_equal [ "Sorcerer" ], affinity.prohibited_paths
    assert_not_includes Talent.choosable_for("Sorcerer"), affinity
    assert_includes Talent.choosable_for("Rogue"), affinity
    assert_not affinity.paragraphs.join.include?("Prohibited")
  end

  test "core talents aren't choosable" do
    assert Talent.choosable_for("Rogue").none?(&:core?)
  end
end

class TalentTextTest < ActiveSupport::TestCase
  test "no stray control characters from the PDF's hyphenation" do
    Talent.all.each do |talent|
      assert_no_match(/[\u0000-\u0009\u000b-\u001f­]/, [ talent.text, talent.note ].join, talent.key)
    end
  end
end
