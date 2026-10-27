# Competence and the Quarry pool stop being pools, and Magus's style moves to
# the talent notes (Grimwild::P6Update.run_mechanics!). Data only; nothing to
# undo. In production it takes a snapshot first (outside a transaction:
# SQLite can't VACUUM INTO inside one), and each character is its own
# transaction.
class MoveTalentMechanicsToPreviewSix < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    DatabaseSnapshot.take if Rails.env.production?
    Grimwild::P6Update.run_mechanics!
  end

  def down
  end
end
