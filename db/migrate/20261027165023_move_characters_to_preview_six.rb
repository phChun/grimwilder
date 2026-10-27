# According to Plan becomes Mastermind and Expertise's skills follow Preview 6
# (Grimwild::P6Update). Data only; nothing to undo. In production it takes a
# snapshot first (outside a transaction: SQLite can't VACUUM INTO inside one),
# and each character is its own transaction.
class MoveCharactersToPreviewSix < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    DatabaseSnapshot.take if Rails.env.production?
    Grimwild::P6Update.run!
  end

  def down
  end
end
