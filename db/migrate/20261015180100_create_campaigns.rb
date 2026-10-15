class CreateCampaigns < ActiveRecord::Migration[8.2]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.string :join_code, null: false
      t.timestamps

      t.index :join_code, unique: true
    end

    create_table :memberships do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :identity, null: false, foreign_key: true
      t.string :role, null: false, default: "player"
      t.timestamps

      t.index [ :campaign_id, :identity_id ], unique: true
    end
  end
end
