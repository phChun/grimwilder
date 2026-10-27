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

ActiveRecord::Schema[8.2].define(version: 2026_10_27_150000) do
  create_table "arcana", force: :cascade do |t|
    t.integer "character_id", null: false
    t.string "name", null: false
    t.string "tier", default: "minor", null: false
    t.string "function", null: false
    t.json "touchstones", default: [], null: false
    t.text "description"
    t.text "limitations"
    t.boolean "expendable", default: false, null: false
    t.boolean "power_pool", default: false, null: false
    t.datetime "used_at"
    t.string "source"
    t.json "rolled_touchstones", default: [], null: false
    t.boolean "lock_ready", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_arcana_on_character_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name", null: false
    t.string "join_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "suspense", default: 0, null: false
    t.string "pitch"
    t.string "setting"
    t.json "party_is", default: [], null: false
    t.string "party_never"
    t.string "group_arc"
    t.datetime "done_at"
    t.index ["done_at"], name: "index_campaigns_on_done_at"
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
    t.json "talent_uses", default: {}, null: false
    t.string "harm_change"
    t.datetime "harm_changed_at"
    t.integer "harm_changed_by_id"
    t.string "status", default: "active", null: false
    t.json "talent_skins", default: {}, null: false
    t.boolean "up_for_grabs", default: false, null: false
    t.json "eldritch_talent_keys", default: [], null: false
    t.datetime "status_changed_at"
    t.string "farewell"
    t.json "talent_choices", default: {}, null: false
    t.json "talent_state", default: {}, null: false
    t.string "stat_progression"
    t.index ["campaign_id"], name: "index_characters_on_campaign_id"
    t.index ["harm_changed_by_id"], name: "index_characters_on_harm_changed_by_id"
    t.index ["identity_id"], name: "index_characters_on_identity_id"
  end

  create_table "identities", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "name"
    t.string "webauthn_user_handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.datetime "last_signed_in_at"
    t.string "plan", default: "free", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
    t.index ["last_signed_in_at"], name: "index_identities_on_last_signed_in_at"
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
    t.datetime "seen_at"
    t.datetime "active_at"
    t.index ["campaign_id", "identity_id"], name: "index_memberships_on_campaign_id_and_identity_id", unique: true
    t.index ["campaign_id"], name: "index_memberships_on_campaign_id"
    t.index ["identity_id"], name: "index_memberships_on_identity_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "identity_id", null: false
    t.integer "character_id"
    t.string "name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", default: "table_talk", null: false
    t.string "speaker_name"
    t.index ["campaign_id", "created_at"], name: "index_messages_on_campaign_id_and_created_at"
    t.index ["campaign_id", "kind"], name: "index_messages_on_campaign_id_and_kind"
    t.index ["campaign_id"], name: "index_messages_on_campaign_id"
    t.index ["character_id"], name: "index_messages_on_character_id"
    t.index ["identity_id"], name: "index_messages_on_identity_id"
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

  create_table "play_session_characters", id: false, force: :cascade do |t|
    t.integer "play_session_id", null: false
    t.integer "character_id", null: false
    t.index ["character_id"], name: "index_play_session_characters_on_character_id"
    t.index ["play_session_id", "character_id"], name: "idx_on_play_session_id_character_id_1d619a4f40", unique: true
  end

  create_table "play_sessions", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "number", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.text "recap"
    t.text "notes"
    t.boolean "standout", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "number"], name: "index_play_sessions_on_campaign_id_and_number", unique: true
    t.index ["campaign_id"], name: "index_play_sessions_on_campaign_id"
    t.index ["campaign_id"], name: "index_play_sessions_one_open_per_campaign", unique: true, where: "ended_at IS NULL"
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
    t.json "phases", default: [], null: false
    t.integer "phase", default: 0, null: false
    t.integer "character_id"
    t.string "refresh"
    t.string "use_key"
    t.integer "arcanum_id"
    t.integer "refills_used", default: 0, null: false
    t.boolean "made_by_talent", default: false, null: false
    t.boolean "tick", default: false, null: false
    t.index ["arcanum_id"], name: "index_pools_on_arcanum_id", unique: true
    t.index ["campaign_id"], name: "index_pools_on_campaign_id"
    t.index ["character_id", "use_key"], name: "index_pools_on_character_id_and_use_key", unique: true, where: "made_by_talent = 0"
    t.index ["character_id"], name: "index_pools_on_character_id"
    t.index ["last_rolled_by_id"], name: "index_pools_on_last_rolled_by_id"
  end

  create_table "roll_calls", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "identity_id", null: false
    t.integer "roll_id"
    t.string "kind", null: false
    t.string "status", default: "open", null: false
    t.string "question"
    t.integer "odds", default: 2, null: false
    t.integer "thorns", default: 0, null: false
    t.json "seats", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_roll_calls_on_campaign_id"
    t.index ["campaign_id"], name: "index_roll_calls_one_open_per_campaign", unique: true, where: "status = 'open'"
    t.index ["identity_id"], name: "index_roll_calls_on_identity_id"
    t.index ["roll_id"], name: "index_roll_calls_on_roll_id"
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
    t.json "assists", default: [], null: false
    t.string "phase"
    t.string "next_phase"
    t.integer "play_session_id"
    t.integer "scene_id"
    t.json "talent_bonuses", default: [], null: false
    t.json "follow_ups", default: [], null: false
    t.json "boosts", default: [], null: false
    t.boolean "refilled", default: false, null: false
    t.string "help_from"
    t.index ["campaign_id", "created_at"], name: "index_rolls_on_campaign_id_and_created_at"
    t.index ["campaign_id"], name: "index_rolls_on_campaign_id"
    t.index ["character_id"], name: "index_rolls_on_character_id"
    t.index ["identity_id"], name: "index_rolls_on_identity_id"
    t.index ["play_session_id"], name: "index_rolls_on_play_session_id"
    t.index ["pool_id"], name: "index_rolls_on_pool_id"
    t.index ["scene_id"], name: "index_rolls_on_scene_id"
  end

  create_table "scenes", force: :cascade do |t|
    t.integer "play_session_id", null: false
    t.integer "campaign_id", null: false
    t.integer "number", null: false
    t.string "title", null: false
    t.text "notes"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "opening_roll_id"
    t.integer "closing_roll_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_scenes_on_campaign_id"
    t.index ["closing_roll_id"], name: "index_scenes_on_closing_roll_id"
    t.index ["opening_roll_id"], name: "index_scenes_on_opening_roll_id"
    t.index ["play_session_id", "number"], name: "index_scenes_on_play_session_id_and_number", unique: true
    t.index ["play_session_id"], name: "index_scenes_on_play_session_id"
    t.index ["play_session_id"], name: "index_scenes_one_open_per_session", unique: true, where: "ended_at IS NULL"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "identity_id", null: false
    t.string "ip_address"
    t.string "user_agent", limit: 4096
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  add_foreign_key "arcana", "characters", on_delete: :cascade
  add_foreign_key "characters", "campaigns"
  add_foreign_key "characters", "identities"
  add_foreign_key "characters", "identities", column: "harm_changed_by_id", on_delete: :nullify
  add_foreign_key "memberships", "campaigns"
  add_foreign_key "memberships", "identities"
  add_foreign_key "messages", "campaigns", on_delete: :cascade
  add_foreign_key "messages", "characters", on_delete: :nullify
  add_foreign_key "messages", "identities"
  add_foreign_key "passkeys", "identities"
  add_foreign_key "play_session_characters", "characters", on_delete: :cascade
  add_foreign_key "play_session_characters", "play_sessions", on_delete: :cascade
  add_foreign_key "play_sessions", "campaigns"
  add_foreign_key "pools", "arcana", on_delete: :cascade
  add_foreign_key "pools", "campaigns"
  add_foreign_key "pools", "characters", on_delete: :cascade
  add_foreign_key "pools", "identities", column: "last_rolled_by_id"
  add_foreign_key "roll_calls", "campaigns"
  add_foreign_key "roll_calls", "identities"
  add_foreign_key "roll_calls", "rolls"
  add_foreign_key "rolls", "campaigns"
  add_foreign_key "rolls", "characters", on_delete: :nullify
  add_foreign_key "rolls", "identities"
  add_foreign_key "rolls", "play_sessions", on_delete: :nullify
  add_foreign_key "rolls", "pools", on_delete: :nullify
  add_foreign_key "rolls", "scenes", on_delete: :nullify
  add_foreign_key "scenes", "campaigns"
  add_foreign_key "scenes", "play_sessions", on_delete: :cascade
  add_foreign_key "scenes", "rolls", column: "closing_roll_id", on_delete: :nullify
  add_foreign_key "scenes", "rolls", column: "opening_roll_id", on_delete: :nullify
  add_foreign_key "sessions", "identities"
end
