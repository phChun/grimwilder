# Scenes the GM prepares ahead (ScenePlan): a title, notes and maybe an
# opening story roll, picked when starting a scene; then it's the scene's.
class CreateScenePlans < ActiveRecord::Migration[8.2]
  def change
    create_table :scene_plans do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :title, null: false
      t.text :notes
      t.string :opening_question
      t.integer :opening_odds
      t.integer :position, null: false, default: 0
      t.references :scene, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
  end
end
