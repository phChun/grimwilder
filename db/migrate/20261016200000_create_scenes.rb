class CreateScenes < ActiveRecord::Migration[8.2]
  # Conditions were plain strings; now { "name", "lasts" } so some can clear after a scene.
  class Character < ActiveRecord::Base
    self.table_name = "characters"
  end

  def up
    create_table :scenes do |t|
      t.references :play_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :campaign, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.text :notes
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.references :opening_roll, foreign_key: { to_table: :rolls, on_delete: :nullify }
      t.references :closing_roll, foreign_key: { to_table: :rolls, on_delete: :nullify }
      t.timestamps
    end
    add_index :scenes, %i[ play_session_id number ], unique: true
    add_index :scenes, :play_session_id, unique: true, where: "ended_at IS NULL", name: "index_scenes_one_open_per_session"

    add_reference :rolls, :scene, foreign_key: { on_delete: :nullify }

    Character.find_each do |character|
      structured = Array(character.conditions).map { _1.is_a?(Hash) ? _1 : { "name" => _1.to_s, "lasts" => nil } }
      character.update_columns(conditions: structured)
    end
  end

  def down
    Character.find_each do |character|
      character.update_columns(conditions: Array(character.conditions).map { _1.is_a?(Hash) ? _1["name"] : _1 })
    end
    remove_reference :rolls, :scene, foreign_key: true
    drop_table :scenes
  end
end
