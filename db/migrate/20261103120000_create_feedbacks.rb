# Feedback from the accounts an admin lets send it (identities.feedback_enabled):
# what they wrote, and the page they were on.
class CreateFeedbacks < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :feedback_enabled, :boolean, null: false, default: false

    create_table :feedbacks do |t|
      t.references :identity, null: false, foreign_key: { on_delete: :cascade }
      t.string :path, null: false # the page they were on, as they saw it (with its query)
      t.string :route # the controller and action it maps to ("campaigns/tables#show"), for whoever reads it
      t.string :user_agent
      t.text :body, null: false
      t.timestamps
    end
    add_index :feedbacks, :created_at
  end
end
