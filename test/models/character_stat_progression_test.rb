require "test_helper"

# The optional stat progression rule (pg. 175): a talent given up, once, for +1 to a stat.
class CharacterStatProgressionTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs) # level 1, Agility 3, one talent chosen
    @pip = identities(:pip)
  end

  test "a free talent slot buys +1 to a stat, which can reach 4, once" do
    refute @tibbs.can_progress_stat?("agility"), "no free slot at level 1 with a talent chosen"
    @tibbs.update!(level: 2)

    @tibbs.progress_stat!("agility", by: @pip)
    assert_equal [ 4, "agility", 1, true ], [ @tibbs.agility, @tibbs.stat_progression, @tibbs.expected_talent_count, @tibbs.talents_full? ]
    assert_equal "Tibbs gives up a talent for +1 Agility.", campaigns(:bramblewood).rolls.last.question
    refute @tibbs.can_progress_stat?("wits"), "once"

    @tibbs.wits = 4
    refute @tibbs.valid?, "only the progressed stat goes past 3"
  end

  test "taking it back gives the slot back, unless a talent has filled it" do
    @tibbs.update!(level: 2)
    @tibbs.progress_stat!("wits", by: @pip)
    @tibbs.undo_stat_progression!
    assert_equal [ 2, nil, 1 ], [ @tibbs.wits, @tibbs.stat_progression, @tibbs.talents_to_choose ]
  end
end
