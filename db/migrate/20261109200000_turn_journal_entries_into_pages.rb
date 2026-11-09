# Journals become pages the player keeps as they like, each with an optional
# title, instead of one per session. The GM may add pages too (by_gm), and
# make them read only for the player (locked). Pages already written keep
# their session as their title.
class TurnJournalEntriesIntoPages < ActiveRecord::Migration[8.2]
  def up
    remove_index :journal_entries, name: "index_journal_entries_on_page"
    rename_table :journal_entries, :journal_pages
    add_column :journal_pages, :title, :string
    add_column :journal_pages, :by_gm, :boolean, null: false, default: false
    add_column :journal_pages, :locked, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE journal_pages SET title = CASE
        WHEN NOT "between" THEN 'Session ' || session_number
        WHEN session_number = 0 THEN 'Before Session 1'
        ELSE 'After Session ' || session_number
      END
    SQL

    remove_column :journal_pages, :session_number
    remove_column :journal_pages, :between
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
