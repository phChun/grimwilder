class AddTalentUses < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :talent_uses, :json, null: false, default: {} # { "inspiration/inspiration" => 2 }: spent

    add_reference :pools, :character, foreign_key: { on_delete: :cascade } # a talent pool (Grenades, Wild Shape…)
    add_column :pools, :refresh, :string # "session" or "scene"
    add_column :pools, :use_key, :string # the Talent::Use it comes from
    add_index :pools, %i[ character_id use_key ], unique: true
  end
end
