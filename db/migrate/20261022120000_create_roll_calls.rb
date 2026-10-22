# A story roll, montage or quarrel waiting on its players to roll their own
# dice (RollCall). One open call per campaign at a time.
class CreateRollCalls < ActiveRecord::Migration[8.2]
  def change
    create_table :roll_calls do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :identity, null: false, foreign_key: true
      t.references :roll, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "open"
      t.string :question
      t.integer :odds, null: false, default: 2
      t.integer :thorns, null: false, default: 0
      t.json :seats, null: false, default: []
      t.timestamps
    end

    add_index :roll_calls, :campaign_id, unique: true, where: "status = 'open'", name: "index_roll_calls_one_open_per_campaign"
  end
end
