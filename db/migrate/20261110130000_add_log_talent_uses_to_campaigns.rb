# The GM's switch for posting each talent use a character spends to the
# table log ("Fen spends inspiration"), replacing each player's own checkbox.
class AddLogTalentUsesToCampaigns < ActiveRecord::Migration[8.2]
  def change
    add_column :campaigns, :log_talent_uses, :boolean, null: false, default: false
  end
end
