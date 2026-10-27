require "test_helper"

# The optional stat progression rule (pg. 175): a talent given up, once, for +1 to a stat.
class CharacterStatProgressionTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs) # level 1, Agility 3, one talent chosen
    @pip = identities(:pip)
  end

  test "a free talent slot buys +1 to a stat, to a max of 3, once" do
    refute @tibbs.can_progress_stat?("wits"), "no free slot at level 1 with a talent chosen"
    @tibbs.update!(level: 2)
    refute @tibbs.can_progress_stat?("agility"), "Agility is already 3"

    @tibbs.progress_stat!("wits", by: @pip)
    assert_equal [ 3, "wits", 1, true ], [ @tibbs.wits, @tibbs.stat_progression, @tibbs.expected_talent_count, @tibbs.talents_full? ]
    assert_equal "Tibbs gives up a talent for +1 Wits.", campaigns(:bramblewood).rolls.last.question
    refute @tibbs.can_progress_stat?("presence"), "once"

    @tibbs.wits = 4
    refute @tibbs.valid?, "no stat goes past 3"
  end

  test "taking it back gives the slot back, unless a talent has filled it" do
    @tibbs.update!(level: 2)
    @tibbs.progress_stat!("wits", by: @pip)
    @tibbs.undo_stat_progression!
    assert_equal [ 2, nil, 1 ], [ @tibbs.wits, @tibbs.stat_progression, @tibbs.talents_to_choose ]
  end

  test "an Adventurer can take it back with a full sheet: Talented's extra slots count" do
    @tibbs.update!(path: "Adventurer", level: 2, talent_keys: %w[ lucky lurker weasel ])
    @tibbs.progress_stat!("wits", by: @pip)
    assert_equal [ 3, true ], [ @tibbs.expected_talent_count, @tibbs.talents_full? ]

    @tibbs.undo_stat_progression!
    assert_equal [ nil, 4, 1 ], [ @tibbs.stat_progression, @tibbs.expected_talent_count, @tibbs.talents_to_choose ]
  end
end
