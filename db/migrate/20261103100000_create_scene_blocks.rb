# Scene blocks: prepared scenes grouped by where the players might go ("The
# castle"), each with notes. A session can say which block it's playing.
class CreateSceneBlocks < ActiveRecord::Migration[8.2]
  def change
    create_table :scene_blocks do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :title, null: false
      t.text :notes
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_reference :scene_plans, :scene_block, foreign_key: { on_delete: :nullify }
    add_reference :play_sessions, :scene_block, foreign_key: { on_delete: :nullify }
  end
end
