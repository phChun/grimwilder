class CreateIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :identities do |t|
      t.string :email_address, null: false
      t.string :name
      t.string :webauthn_user_handle
      t.timestamps

      t.index :email_address, unique: true
      t.index :webauthn_user_handle, unique: true
    end

    create_table :sessions do |t|
      t.references :identity, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent, limit: 4096
      t.timestamps
    end

    create_table :magic_links do |t|
      t.string :email_address, null: false
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.timestamps

      t.index :code, unique: true
      t.index :expires_at
    end

    create_table :passkeys do |t|
      t.references :identity, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :name, null: false
      t.datetime :last_used_at
      t.timestamps

      t.index :external_id, unique: true
    end
  end
end
