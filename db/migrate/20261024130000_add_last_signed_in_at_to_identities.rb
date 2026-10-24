# Sessions are deleted on sign-out, so they can't say when someone last signed
# in. Start from the newest session each identity still has.
class AddLastSignedInAtToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :last_signed_in_at, :datetime
    add_index :identities, :last_signed_in_at

    up_only do
      execute <<~SQL
        UPDATE identities SET last_signed_in_at =
          (SELECT MAX(sessions.created_at) FROM sessions WHERE sessions.identity_id = identities.id)
      SQL
    end
  end
end
