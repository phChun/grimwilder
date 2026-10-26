# Arcana (pg. 40–43): magic items a character holds, with a function, more
# touchstones, a tier and maybe a power pool (kept as a Pool with arcanum_id).
class CreateArcana < ActiveRecord::Migration[8.2]
  def change
    create_table :arcana do |t|
      t.references :character, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :tier, null: false, default: "minor"
      t.string :function, null: false
      t.json :touchstones, null: false, default: []
      t.text :description
      t.text :limitations
      t.boolean :expendable, null: false, default: false
      t.boolean :power_pool, null: false, default: false
      t.datetime :used_at
      t.string :source # the talent that granted it, e.g. "archivist"
      t.json :rolled_touchstones, null: false, default: [] # Magnum Opus: this session's roll
      t.boolean :lock_ready, null: false, default: false # Magnum Opus: one touchstone may be locked in from the roll
      t.timestamps
    end

    add_reference :pools, :arcanum, foreign_key: { on_delete: :cascade }, index: { unique: true }
  end
end
