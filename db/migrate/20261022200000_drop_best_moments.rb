# Best moments (and the chat's star that nominated them) are gone. The
# blocks put the tables back on a rollback, empty.
class DropBestMoments < ActiveRecord::Migration[8.2]
  def change
    drop_table :play_session_nominations do |t|
      t.references :play_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :character, null: false, foreign_key: { on_delete: :cascade }
      t.references :identity, null: false, foreign_key: true
      t.references :message, foreign_key: { on_delete: :nullify }
      t.text :text, null: false
      t.timestamps
      t.index [ :play_session_id, :character_id, :identity_id ], unique: true, name: "index_nominations_one_per_nominator"
    end

    drop_table :play_session_moments do |t|
      t.references :play_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :character, null: false, foreign_key: { on_delete: :cascade }
      t.references :identity, null: false, foreign_key: true
      t.text :text, null: false
      t.timestamps
      t.index [ :play_session_id, :character_id ], unique: true
    end
  end
end
