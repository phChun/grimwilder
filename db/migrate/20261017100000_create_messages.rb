class CreateMessages < ActiveRecord::Migration[8.2]
  def change
    create_table :messages do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :identity, null: false, foreign_key: true
      t.references :character, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.text :body, null: false
      t.timestamps
    end

    add_index :messages, %i[ campaign_id created_at ]
  end
end
