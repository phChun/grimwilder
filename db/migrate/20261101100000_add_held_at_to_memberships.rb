# A GM membership held because its account's plan runs fewer campaigns
# (Identity::Plans#apply_plan!). A campaign whose GMs are all held is on hold.
class AddHeldAtToMemberships < ActiveRecord::Migration[8.2]
  def change
    add_column :memberships, :held_at, :datetime
  end
end
