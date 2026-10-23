class AddDoneAtToCampaigns < ActiveRecord::Migration[8.2]
  def change
    add_column :campaigns, :done_at, :datetime
    add_index :campaigns, :done_at
  end
end
