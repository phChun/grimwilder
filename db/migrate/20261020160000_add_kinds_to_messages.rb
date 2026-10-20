# Table chat kinds (narration, npc, in_character, table_talk, whisper), an NPC's
# name, and best-moment nominations: a star on a chat line that fills in the
# moment prompt when the next session starts (pg. 31).
class AddKindsToMessages < ActiveRecord::Migration[8.2]
  def up
    add_column :messages, :kind, :string, default: "table_talk", null: false
    add_column :messages, :speaker_name, :string
    add_index :messages, [ :campaign_id, :kind ]

    # Lines spoken as a character were in character; everything else was table talk.
    execute "UPDATE messages SET kind = 'in_character' WHERE character_id IS NOT NULL"

    create_table :play_session_nominations do |t|
      t.references :play_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :character, null: false, foreign_key: { on_delete: :cascade }
      t.references :identity, null: false, foreign_key: true
      t.references :message, foreign_key: { on_delete: :nullify }
      t.text :text, null: false
      t.timestamps
    end
    add_index :play_session_nominations, [ :play_session_id, :character_id, :identity_id ], unique: true, name: "index_nominations_one_per_nominator"
  end

  def down
    drop_table :play_session_nominations
    remove_index :messages, [ :campaign_id, :kind ]
    remove_column :messages, :speaker_name
    remove_column :messages, :kind
  end
end
