# A nightly copy of the primary database, written next to it on the droplet's
# volume (storage/backups) and kept for KEEP days. It covers a bad migration or
# a bug that mangles data; DigitalOcean's daily droplet backups carry these
# copies off the machine, which covers losing the droplet. VACUUM INTO writes a
# consistent copy while the app keeps running. Runs from config/recurring.yml.
class DatabaseSnapshot
  KEEP = 7

  def self.take(dir: Rails.root.join("storage/backups"), on: Date.current, keep: KEEP)
    new(dir:, keep:).take(on)
  end

  def initialize(dir:, keep:)
    @dir = Pathname(dir)
    @keep = keep
  end

  # Returns the snapshot's path. Taking a second snapshot on the same day replaces the first.
  def take(date)
    @dir.mkpath
    path = @dir.join("grimwilder-#{date.iso8601}.sqlite3")
    path.delete if path.exist? # VACUUM INTO won't overwrite a file

    ActiveRecord::Base.with_connection do |connection|
      connection.execute("VACUUM INTO #{connection.quote(path.to_s)}")
    end

    prune
    path
  end

  private
    def prune
      snapshots = @dir.glob("grimwilder-*.sqlite3").sort
      snapshots.first(snapshots.size - @keep).each(&:delete) if snapshots.size > @keep
    end
end
