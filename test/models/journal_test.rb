require "test_helper"

class JournalTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @pip = memberships(:pip_player)
    @journal = @pip.journal
  end

  test "before any session, the one page is the one before Session 1" do
    assert_equal [ "before" ], @journal.pages.map(&:key)
    assert @journal.current_page.current
  end

  test "a page per session, and between them only the ones written or happening now" do
    first = PlaySession.start!(@campaign, characters: [], by: identities(:gwen))
    @journal.write!(@journal.page("before"), "Packed my bags.")
    assert_equal %w[ session-1 before ], @journal.pages.map(&:key)
    assert_equal "session-1", @journal.current_page.key

    first.end!(by: identities(:gwen))
    PlaySession.start!(@campaign, characters: [], by: identities(:gwen)).end!(by: identities(:gwen))
    assert_equal %w[ after-2 session-2 session-1 before ], @journal.pages.map(&:key)
    assert_equal [ "After Session 2", "after-2" ], [ @journal.current_page.title, @journal.current_page.key ]

    @journal.write!(@journal.page("session-1"), "  The bridge.  ")
    assert_equal [ "The bridge.", "Packed my bags." ], @journal.pages(written_only: true).map(&:body)
    assert_not_includes @journal.pages.map(&:key), "after-1", "an empty stretch with nothing written isn't listed"
    assert_equal "After Session 1", @journal.page("after-1").title, "but it can still be written"
    assert_nil @journal.page("after-3")
    assert_nil @journal.page("session-0")

    @journal.write!(@journal.page("session-1"), " ")
    assert_equal [ "Packed my bags." ], @journal.pages(written_only: true).map(&:body), "a blank page clears it"
  end

  test "the GM reads it while it's shared; nobody else does, and only the player writes" do
    gm = memberships(:gwen_gm)
    assert @journal.readable_by?(@pip)
    assert @journal.readable_by?(gm), "shared by default"
    assert @journal.writable_by?(@pip)
    assert_not @journal.writable_by?(gm)

    @pip.update!(journal_shared: false)
    assert_not @journal.readable_by?(gm)
    assert_not gm.journal.writable_by?(gm), "the GM keeps no journal"
  end

  test "a reset leaves the writing, by session number" do
    PlaySession.start!(@campaign, characters: [], by: identities(:gwen))
    @journal.write!(@journal.page("session-1"), "The bridge.")
    @campaign.reset!(by: identities(:gwen))
    assert_equal 1, @pip.journal_entries.count
  end
end
