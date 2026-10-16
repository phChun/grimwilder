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

ActiveRecord::Schema[8.2].define(version: 2026_10_16_160000) do
  create_table "campaigns", force: :cascade do |t|
    t.string "name", null: false
    t.string "join_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_campaigns_on_join_code", unique: true
  end

  create_table "characters", force: :cascade do |t|
    t.integer "identity_id", null: false
    t.integer "campaign_id"
    t.string "name", null: false
    t.string "path", null: false
    t.integer "level", default: 1, null: false
    t.integer "xp", default: 0, null: false
    t.integer "brawn", default: 1, null: false
    t.integer "agility", default: 1, null: false
    t.integer "wits", default: 1, null: false
    t.integer "presence", default: 1, null: false
    t.integer "spark", default: 0, null: false
    t.integer "thread", default: 2, null: false
    t.boolean "marked_brawn", default: false, null: false
    t.boolean "marked_agility", default: false, null: false
    t.boolean "marked_wits", default: false, null: false
    t.boolean "marked_presence", default: false, null: false
    t.boolean "bloodied", default: false, null: false
    t.boolean "rattled", default: false, null: false
    t.boolean "desperate", default: false, null: false
    t.json "conditions", default: [], null: false
    t.json "backgrounds", default: [], null: false
    t.json "traits", default: [], null: false
    t.string "not_trait"
    t.json "desires", default: [], null: false
    t.string "not_desire"
    t.json "features", default: [], null: false
    t.string "weapons"
    t.json "weapon_styles", default: [], null: false
    t.json "arcs", default: [], null: false
    t.json "bonds", default: [], null: false
    t.text "talents"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "talent_keys", default: [], null: false
    t.index ["campaign_id"], name: "index_characters_on_campaign_id"
    t.index ["identity_id"], name: "index_characters_on_identity_id"
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

  create_table "pools", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.string "name", null: false
    t.string "kind", default: "task", null: false
    t.integer "starting_size", null: false
    t.integer "size", null: false
    t.boolean "hidden", default: false, null: false
    t.json "last_dice", default: [], null: false
    t.integer "last_dropped"
    t.string "last_action"
    t.integer "last_rolled_by_id"
    t.datetime "last_rolled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_pools_on_campaign_id"
    t.index ["last_rolled_by_id"], name: "index_pools_on_last_rolled_by_id"
  end

  create_table "rolls", force: :cascade do |t|
    t.integer "campaign_id"
    t.integer "identity_id", null: false
    t.integer "character_id"
    t.integer "pool_id"
    t.string "kind", null: false
    t.string "name", null: false
    t.string "stat"
    t.json "dice", default: [], null: false
    t.json "thorns", default: [], null: false
    t.integer "stat_dice", default: 0, null: false
    t.integer "help_dice", default: 0, null: false
    t.integer "spark_spent", default: 0, null: false
    t.json "damage_reasons", default: [], null: false
    t.string "outcome"
    t.boolean "critical", default: false, null: false
    t.boolean "spark_gained", default: false, null: false
    t.string "pool_action"
    t.integer "dropped"
    t.integer "remaining"
    t.boolean "gm_only", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "question"
    t.json "sides", default: [], null: false
    t.string "winner"
    t.index ["campaign_id", "created_at"], name: "index_rolls_on_campaign_id_and_created_at"
    t.index ["campaign_id"], name: "index_rolls_on_campaign_id"
    t.index ["character_id"], name: "index_rolls_on_character_id"
    t.index ["identity_id"], name: "index_rolls_on_identity_id"
    t.index ["pool_id"], name: "index_rolls_on_pool_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "identity_id", null: false
    t.string "ip_address"
    t.string "user_agent", limit: 4096
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  add_foreign_key "characters", "campaigns"
  add_foreign_key "characters", "identities"
  add_foreign_key "memberships", "campaigns"
  add_foreign_key "memberships", "identities"
  add_foreign_key "passkeys", "identities"
  add_foreign_key "pools", "campaigns"
  add_foreign_key "pools", "identities", column: "last_rolled_by_id"
  add_foreign_key "rolls", "campaigns"
  add_foreign_key "rolls", "characters", on_delete: :nullify
  add_foreign_key "rolls", "identities"
  add_foreign_key "rolls", "pools", on_delete: :nullify
  add_foreign_key "sessions", "identities"
end
