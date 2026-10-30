class CreateInterests < ActiveRecord::Migration[8.2]
  def change
    create_table :interests do |t|
      t.string :email_address, null: false
      t.string :role
      t.text :note
      t.timestamps
    end
    add_index :interests, :email_address, unique: true
  end
end
