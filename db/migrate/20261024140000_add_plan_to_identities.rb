class AddPlanToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :plan, :string, null: false, default: "free"
  end
end
