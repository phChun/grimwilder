require "test_helper"

class JournalTest < ActiveSupport::TestCase
  setup do
    @pip = memberships(:pip_player)
    @gm = memberships(:gwen_gm)
    @journal = @pip.journal
  end

  test "pages are written when the player likes, starred first, then newest, with an optional title" do
    @journal.write!(@pip, title: "  The bridge ", body: "  We crossed it.  ")
    travel 1.minute
    untitled = @journal.write!(@pip, title: " ", body: "Then the river.")

    assert_equal [ "Then the river.", "We crossed it." ], @journal.pages_for(@pip).map(&:body)
    assert_equal "The bridge", @pip.journal_pages.find_by(body: "We crossed it.").heading
    assert_nil untitled.title
    assert_equal untitled.created_at.strftime("%B %-d, %Y"), untitled.heading, "an untitled page goes by its day"
    assert_raises(ActiveRecord::RecordInvalid) { @journal.write!(@pip, title: "", body: " ") }
    assert @journal.write!(@pip, title: "Later", body: "").persisted?, "a title is enough"

    @pip.journal_pages.find_by(body: "We crossed it.").update!(favorite: true)
    assert_equal [ "We crossed it.", "", "Then the river." ], @journal.pages_for(@pip).map(&:body)
    assert_equal [ "We crossed it.", "Then the river.", "" ], @journal.pages_for(@pip, sort: "chronologically").map(&:body)
    travel 1.minute
    @pip.journal_pages.find_by(body: "Then the river.").update!(body: "Then the river, twice.")
    assert_equal "Then the river, twice.", @journal.pages_for(@pip, sort: "last_updated").first.body
    assert_equal @journal.pages_for(@pip).to_a, @journal.pages_for(@pip, sort: "drop table").to_a, "an unknown sort is favorites first"
  end

  test "every player starts with Character Secrets, starred, for the GM and the player both" do
    player = campaigns(:bramblewood).memberships.create!(identity: identities(:stranger), role: :player)
    secrets = player.journal_pages.sole
    assert_equal [ "Character Secrets", "", true ], [ secrets.title, secrets.body, secrets.favorite ]
    assert secrets.shared?
    assert player.journal.editable_by?(secrets, player)
    assert player.journal.editable_by?(secrets, @gm)
    player.update!(journal_shared: false)
    assert_equal [ secrets ], player.journal.pages_for(@gm).to_a

    assert_empty campaigns(:bramblewood).memberships.create!(identity: identities(:ada), role: :gm).journal_pages, "a GM keeps none"
  end

  test "the GM reads it while it's shared, and always reads the GM's own pages" do
    mine = @journal.write!(@pip, title: nil, body: "Mine.")
    theirs = @journal.write!(@gm, title: "Who you were", body: "A thief, once.", locked: true)
    assert theirs.by_gm? && theirs.locked?
    assert_not @journal.write!(@pip, title: nil, body: "Tried.", locked: true).locked?, "only the GM locks pages"

    assert_includes @journal.pages_for(@gm), mine, "shared by default"
    @pip.update!(journal_shared: false)
    assert_equal [ theirs ], @journal.pages_for(@gm).to_a
    assert_includes @journal.pages_for(@pip), theirs

    other = @pip.campaign.memberships.create!(identity: identities(:stranger), role: :player)
    assert_empty @journal.pages_for(other), "other players never read it"
    assert_not @gm.journal.readable_by?(@gm), "the GM keeps no journal"
  end

  test "the player changes their own pages and the GM's unlocked ones; the GM only the GM's" do
    mine = @journal.write!(@pip, title: nil, body: "Mine.")
    locked = @journal.write!(@gm, title: nil, body: "A secret.", locked: true)
    open = @journal.write!(@gm, title: nil, body: "Fill this in.", locked: false)

    assert @journal.editable_by?(mine, @pip)
    assert_not @journal.editable_by?(locked, @pip)
    assert @journal.editable_by?(open, @pip)
    assert_not @journal.editable_by?(mine, @gm)
    assert @journal.editable_by?(locked, @gm)
  end
end
