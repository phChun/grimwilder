# When each member's open pages last checked in, and last while in use: the
# presence halos on their chat lines (Membership#presence).
class AddPresenceToMemberships < ActiveRecord::Migration[8.2]
  def change
    add_column :memberships, :seen_at, :datetime
    add_column :memberships, :active_at, :datetime
  end
end
