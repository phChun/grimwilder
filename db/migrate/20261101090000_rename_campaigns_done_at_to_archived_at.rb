class RenameCampaignsDoneAtToArchivedAt < ActiveRecord::Migration[8.2]
  def change
    rename_column :campaigns, :done_at, :archived_at
  end
end
