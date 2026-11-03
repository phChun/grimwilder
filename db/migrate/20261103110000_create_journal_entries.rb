# A player's journal at a campaign: a page per session, or per stretch between
# sessions. Pages are keyed by session number rather than id, so a campaign's
# reset (which deletes its sessions) leaves the writing alone. The GM may read
# it unless the player turns that off.
class CreateJournalEntries < ActiveRecord::Migration[8.2]
  def change
    create_table :journal_entries do |t|
      t.references :membership, null: false, foreign_key: { on_delete: :cascade }
      t.integer :session_number, null: false # 0 with between: before Session 1
      t.boolean :between, null: false, default: false # after that session, before the next
      t.text :body, null: false
      t.timestamps
    end
    add_index :journal_entries, %i[ membership_id session_number between ], unique: true, name: "index_journal_entries_on_page"
    add_column :memberships, :journal_shared, :boolean, null: false, default: true
  end
end
