# A GM blocks someone from a campaign: they're removed, and its invite link
# won't let them back in until the block is lifted.
class CreateCampaignBlocks < ActiveRecord::Migration[8.2]
  def change
    create_table :campaign_blocks do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :identity, null: false, foreign_key: { on_delete: :cascade }
      t.references :blocked_by, foreign_key: { to_table: :identities, on_delete: :nullify }
      t.timestamps
    end
    add_index :campaign_blocks, %i[ campaign_id identity_id ], unique: true
  end
end
