# A GM's whisper goes to one player, picked by their character: recipient is
# that player, recipient_name the character's name, copied in like name.
class AddRecipientToMessages < ActiveRecord::Migration[8.2]
  def change
    add_reference :messages, :recipient, foreign_key: { to_table: :identities, on_delete: :nullify }
    add_column :messages, :recipient_name, :string
  end
end
