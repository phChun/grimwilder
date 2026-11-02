# The GM can turn the invite link off (and on again), so no one new joins
# without making a new link.
class AddJoinLinkEnabledToCampaigns < ActiveRecord::Migration[8.2]
  def change
    add_column :campaigns, :join_link_enabled, :boolean, null: false, default: true
  end
end
