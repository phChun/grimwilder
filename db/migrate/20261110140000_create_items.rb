# Important items a character carries, beside their arcana: a name and what
# matters about it (Item).
class CreateItems < ActiveRecord::Migration[8.2]
  def change
    create_table :items do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
  end
end
