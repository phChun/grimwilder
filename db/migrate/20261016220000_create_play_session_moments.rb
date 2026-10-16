class CreatePlaySessionMoments < ActiveRecord::Migration[8.2]
  def change
    create_table :play_session_moments do |t|
      t.references :play_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :character, null: false, foreign_key: { on_delete: :cascade }
      t.references :identity, null: false, foreign_key: true
      t.text :text, null: false
      t.timestamps
    end
    add_index :play_session_moments, %i[ play_session_id character_id ], unique: true
  end
end
