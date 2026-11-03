class CreateTableQuestions < ActiveRecord::Migration[8.2]
  def change
    create_table :table_questions do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :identity, null: false, foreign_key: true
      t.text :body
      t.json :choices, null: false, default: []
      t.datetime :closed_at
      t.timestamps
    end

    create_table :table_answers do |t|
      t.references :table_question, null: false, foreign_key: { on_delete: :cascade }
      t.references :membership, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :choice
      t.text :body
      t.datetime :answered_at
      t.timestamps
      t.index %i[ table_question_id membership_id ], unique: true
    end
  end
end
