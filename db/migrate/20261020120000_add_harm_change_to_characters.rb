# Who last changed a character's marks, harm or conditions, and what changed,
# so the sheet can say "GM cleared Bloodied · 3m ago" when it wasn't the owner.
class AddHarmChangeToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :harm_change, :string
    add_column :characters, :harm_changed_at, :datetime
    add_reference :characters, :harm_changed_by, foreign_key: { to_table: :identities, on_delete: :nullify }
  end
end
