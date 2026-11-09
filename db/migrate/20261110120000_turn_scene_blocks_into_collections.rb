# Scene blocks become scene collections, and a session no longer picks one:
# starting a scene offers every collection's scenes. A prepared scene keeps
# only the question for a story roll as it opens (story_question), and the
# scene started from it carries the question too: the GM picks the odds and
# who rolls in the story roll modal that opens with the scene.
class TurnSceneBlocksIntoCollections < ActiveRecord::Migration[8.2]
  def change
    remove_reference :play_sessions, :scene_block, index: true, foreign_key: { on_delete: :nullify }
    rename_table :scene_blocks, :scene_collections
    rename_column :scene_plans, :scene_block_id, :scene_collection_id

    rename_column :scene_plans, :opening_question, :story_question
    remove_column :scene_plans, :opening_odds, :integer
    add_column :scenes, :story_question, :string
  end
end
