# An admin can remove an account (Identity::Removal). The table log, chat,
# roll calls and polls it leaves behind stay, with no one's name on them.
class KeepHistoryOfRemovedAccounts < ActiveRecord::Migration[8.2]
  def change
    change_column_null :rolls, :identity_id, true
    change_column_null :messages, :identity_id, true
    change_column_null :roll_calls, :identity_id, true
    change_column_null :table_questions, :identity_id, true
  end
end
