require "test_helper"

class TalentTest < ActiveSupport::TestCase
  test "each path lists its core talent first, then the rest A to Z" do
    Talent.groups.each do |group|
      talents = group.talents
      rest = talents.reject(&:core?)
      assert talents.first.core?, group.name if group.path?
      assert_equal rest.map { _1.name.downcase }.sort, rest.map { _1.name.downcase }, group.name
    end
    assert_equal %w[ Pact Affliction Blood\ Rituals Knowing\ Gaze ], Talent.groups.find { _1.key == "warlock" }.talents.first(4).map(&:name)
  end

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

  test "the YAML loads safely, and every page is in the book" do
    assert Psych.safe_load_file(Rails.root.join("config/talents.yml"))
    Talent.all.each { |talent| assert_includes 1..200, talent.page, talent.key }
    Talent.groups.each { |group| assert_includes 1..200, group.page, group.key }
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

  test "a talent only one path may take" do
    folk_hero = Talent.find("folk-hero")

    assert_equal [ "Bard" ], folk_hero.only_paths
    assert_includes Talent.choosable_for("Bard"), folk_hero
    assert_not_includes Talent.choosable_for("Rogue"), folk_hero
    assert_not folk_hero.paragraphs.join.include?("Only]")
    assert_equal %w[ folk-hero mind-blast monster-menagerie ], Talent.all.select { _1.only_paths.any? }.map(&:key).sort
  end

  test "core talents aren't choosable" do
    assert Talent.choosable_for("Rogue").none?(&:core?)
  end
end

class TalentChoiceTest < ActiveSupport::TestCase
  # The book's text-layer typos, fixed in the options: { option => as printed }.
  # Hyphens and spaces are ignored already, so "onehanded" matches "one-handed".
  TYPO_FIXES = {}.freeze

  test "every choice is well formed" do
    choices = Talent.all.flat_map(&:choices)
    assert_operator choices.size, :>=, 16

    choices.each do |choice|
      assert_match(/\A[a-z][a-z-]*\z/, choice.key, choice.id)
      assert choice.label.present?, choice.id
      assert_operator choice.label.length, :<=, 30, choice.id
      assert_operator choice.noun.length, :<=, 30, choice.id
      assert choice.plural, "#{choice.id}: say the plural of #{choice.noun.inspect}; Rails would pluralize its last word" if choice.noun.match?(/ (of|or|and|you) /)
      assert_operator choice.pick, :>=, 1, choice.id
      assert choice.growth.keys.all? { (2..7).cover?(_1) }, choice.id
      assert choice.growth.values.all?(&:positive?), choice.id
      assert choice.source, "#{choice.id}'s same_as doesn't resolve"
      assert choice.options.any? || choice.open? || choice.from_picks?, "#{choice.id} has nothing to pick from"
      assert_equal choice.options.map(&:downcase).uniq.size, choice.options.size, "#{choice.id} repeats an option"
      assert choice.options.all? { _1 == _1.strip && _1.present? }, choice.id
      assert_operator choice.min_each, :<=, 0, "#{choice.id} min_each needs groups" unless choice.grouped?
      if choice.same_as
        assert_empty choice.from, "#{choice.id} has same_as and its own list"
        assert_empty choice.groups, choice.id
      end
      assert_equal choice.from_picks.size, choice.picks_sources.size, "#{choice.id}'s from_picks don't all resolve"
      assert_empty choice.from + choice.groups.keys, "#{choice.id} has from_picks and its own list" if choice.from_picks?
      if choice.crucible
        tables = choice.roll_crucible.tables.map(&:name)
        assert_includes tables, choice.table, choice.id if choice.table
      end
      assert choice.open?, "#{choice.id}: a school goes with a theorem the player names" if choice.school?
      assert_empty choice.hints.keys - choice.options, "#{choice.id} has hints for options it doesn't list"
    end

    Talent.all.each do |talent|
      assert_equal talent.choices.map(&:key).uniq, talent.choices.map(&:key), talent.key
      assert_operator talent.choices.filter_map(&:crucible).uniq.size, :<=, 1, "#{talent.key}: its form rolls on one crucible"
    end
  end

  test "every option in a talent's own list comes from its text" do
    squash = ->(text) { text.to_s.downcase.gsub(/[\s\-‐–—]+/, "") }

    Talent.all.each do |talent|
      talent.choices.reject { _1.same_as || _1.from_list }.each do |choice|
        choice.options.each do |option|
          printed = TYPO_FIXES.fetch(option, option)
          assert_includes squash.(talent.text), squash.(printed), "#{choice.id}: #{option.inspect} isn't in the text"
        end
      end
    end
  end

  test "lists, groups and growth read as the book has them" do
    skills = Talent.find("expertise").choice(:skills)
    assert_equal [ "Above board", "Below table" ], skills.option_groups.keys
    assert_equal [ 3, 4, 5 ], [ 1, 3, 6 ].map { skills.slots_at(_1) }
    assert_equal "Below table", skills.group_of("stealth")

    moxie = Talent.find("natural-moxie").choice(:skills)
    assert_equal skills.options, moxie.options
    assert_equal 2, moxie.slots_at(6)

    sorcery = Talent.find("sorcery").choice(:paths)
    assert_equal 1, sorcery.min_each
    assert_equal "Touchstones", sorcery.heading
    assert_equal "source or technique", sorcery.noun
    assert_equal "sources or techniques", sorcery.nouns
    assert_equal "4 sources or techniques", sorcery.to_s
    assert_equal sorcery.options, Talent.find("eldritch-affinity").choice(:paths).options

    assert_includes Talent.find("weapon-mastery").choice(:style).options, "one-handed"
    assert Talent.find("true-shape").choice(:form).open?
    assert_equal "skill", skills.noun
  end

  test "crucibles, other picks and the book's lists" do
    words = Talent.find("hidden-magic").choice(:words)
    assert_equal [ 6, 8, 12 ], [ 1, 2, 6 ].map { words.slots_at(_1) }
    assert_equal "Words of power", words.roll_crucible.name
    assert_equal "words", Talent.find("hidden-magic").uses.sole.named_by

    assert_equal %w[ spellcraft/theorems arcane-training/theorems ], Talent.find("mastered-theorem").choice(:theorem).picks_sources.map(&:id)
    assert_equal Grimwild.magic_schools.keys, Talent.find("specialty-school").choice(:school).options
    assert_includes Grimwild.magic_schools.keys, "necromancy"

    pact = Talent.find("pact")
    assert_equal %w[ natures desires name trappings communication following ], pact.choices.map(&:key)
    assert_equal "Nature", pact.choice(:natures).table
    assert_not pact.choice(:following).open?

    assert Talent.find("spellcraft").choice(:theorems).school?
    assert_equal [ "wild fire", "evocation" ], Talent::Choice.split_school("wild fire (evocation)")
    assert_equal [ "wild fire", nil ], Talent::Choice.split_school("wild fire")
    assert_equal "wild fire (evocation)", Talent::Choice.join_school(" wild  fire ", "Evocation")
    assert_equal "wild fire", Talent::Choice.join_school("wild fire", "")
  end
end

class TalentArcanaGrantTest < ActiveSupport::TestCase
  test "every arcana grant is well formed" do
    grants = Talent.all.flat_map(&:arcana)
    assert_equal %w[ archivist archivist infusion magnum-opus trophies ], grants.map(&:talent_key).sort

    grants.each do |grant|
      assert_includes Arcanum::TIERS, grant.tier, grant.talent_key
      assert_operator grant.count, :>=, 1, grant.talent_key
      assert grant.growth.keys.all? { (2..7).cover?(_1) }, grant.talent_key
      assert_equal "mythic", grant.tier, "#{grant.talent_key}: an opus is mythic" if grant.opus
    end
  end
end

class TalentTextTest < ActiveSupport::TestCase
  test "no stray control characters from the PDF's hyphenation" do
    Talent.all.each do |talent|
      assert_no_match(/[\u0000-\u0009\u000b-\u001f­]/, [ talent.text, talent.note ].join, talent.key)
    end
  end
end
