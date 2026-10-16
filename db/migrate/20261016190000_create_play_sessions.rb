class CreatePlaySessions < ActiveRecord::Migration[8.2]
  def change
    create_table :play_sessions do |t|
      t.references :campaign, null: false, foreign_key: true
      t.integer :number, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.text :recap # "Previously on…", by the GM at the start
      t.text :notes # by the GM at the end
      t.boolean :standout, null: false, default: false
      t.timestamps
    end
    add_index :play_sessions, %i[ campaign_id number ], unique: true
    add_index :play_sessions, :campaign_id, unique: true, where: "ended_at IS NULL", name: "index_play_sessions_one_open_per_campaign"

    create_join_table :play_sessions, :characters, table_name: :play_session_characters do |t|
      t.index %i[ play_session_id character_id ], unique: true
      t.index :character_id
    end
    add_foreign_key :play_session_characters, :play_sessions, on_delete: :cascade
    add_foreign_key :play_session_characters, :characters, on_delete: :cascade

    add_reference :rolls, :play_session, foreign_key: { on_delete: :nullify }
    add_column :campaigns, :suspense, :integer, null: false, default: 0
  end
end
