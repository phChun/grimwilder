require "test_helper"

class DatabaseSnapshotTest < ActiveSupport::TestCase
  # VACUUM can't run inside the transaction each test is normally wrapped in.
  self.use_transactional_tests = false

  setup { @dir = Pathname(Dir.mktmpdir) }
  teardown { FileUtils.remove_entry(@dir) }

  test "writes a readable copy of the database named for the day" do
    path = DatabaseSnapshot.take(dir: @dir, on: Date.new(2026, 10, 24))

    assert_equal @dir.join("grimwilder-2026-10-24.sqlite3"), path
    copy = SQLite3::Database.new(path.to_s, readonly: true)
    tables = copy.execute("SELECT name FROM sqlite_master WHERE type = 'table'").flatten
    copy.close
    assert_includes tables, "campaigns"
  end

  test "a second snapshot on the same day replaces the first" do
    DatabaseSnapshot.take(dir: @dir, on: Date.new(2026, 10, 24))
    DatabaseSnapshot.take(dir: @dir, on: Date.new(2026, 10, 24))

    assert_equal 1, @dir.glob("grimwilder-*.sqlite3").size
  end

  test "keeps only the newest snapshots" do
    (1..5).each { |day| DatabaseSnapshot.take(dir: @dir, on: Date.new(2026, 10, day), keep: 3) }

    assert_equal %w[ grimwilder-2026-10-03.sqlite3 grimwilder-2026-10-04.sqlite3 grimwilder-2026-10-05.sqlite3 ],
      @dir.glob("grimwilder-*.sqlite3").map { |path| path.basename.to_s }.sort
  end
end
