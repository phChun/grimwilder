class AddAdminToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :admin, :boolean, default: false, null: false
  end
end
