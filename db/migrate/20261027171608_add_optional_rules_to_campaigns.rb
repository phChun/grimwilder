# The optional rules a GM turns on for the table (pg. 175–180), e.g.
# weapon styles (Campaign::OptionalRules).
class AddOptionalRulesToCampaigns < ActiveRecord::Migration[8.2]
  def change
    add_column :campaigns, :optional_rules, :json, default: [], null: false
  end
end
