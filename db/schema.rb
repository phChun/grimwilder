# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_10_15_180100) do
  create_table "campaigns", force: :cascade do |t|
    t.string "name", null: false
    t.string "join_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_campaigns_on_join_code", unique: true
  end

  create_table "identities", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "name"
    t.string "webauthn_user_handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
    t.index ["webauthn_user_handle"], name: "index_identities_on_webauthn_user_handle", unique: true
  end

  create_table "magic_links", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "identity_id", null: false
    t.string "role", default: "player", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "identity_id"], name: "index_memberships_on_campaign_id_and_identity_id", unique: true
    t.index ["campaign_id"], name: "index_memberships_on_campaign_id"
    t.index ["identity_id"], name: "index_memberships_on_identity_id"
  end

  create_table "passkeys", force: :cascade do |t|
    t.integer "identity_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "name", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_passkeys_on_external_id", unique: true
    t.index ["identity_id"], name: "index_passkeys_on_identity_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "identity_id", null: false
    t.string "ip_address"
    t.string "user_agent", limit: 4096
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  add_foreign_key "memberships", "campaigns"
  add_foreign_key "memberships", "identities"
  add_foreign_key "passkeys", "identities"
  add_foreign_key "sessions", "identities"
end
