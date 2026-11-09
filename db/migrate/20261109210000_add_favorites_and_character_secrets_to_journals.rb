# Players star the pages they want on top (favorite), and every player's
# journal starts with Character Secrets: the GM's page, open for the player to
# write in too, starred. It may stay empty, so a page needs a title or words.
class AddFavoritesAndCharacterSecretsToJournals < ActiveRecord::Migration[8.2]
  def up
    add_column :journal_pages, :favorite, :boolean, null: false, default: false
    change_column_default :journal_pages, :body, from: nil, to: ""

    execute <<~SQL
      INSERT INTO journal_pages (membership_id, title, body, by_gm, locked, favorite, created_at, updated_at)
      SELECT id, 'Character Secrets', '', TRUE, FALSE, TRUE, created_at, created_at
      FROM memberships WHERE role = 'player'
    SQL
  end

  def down
    execute "DELETE FROM journal_pages WHERE title = 'Character Secrets' AND body = ''"
    change_column_default :journal_pages, :body, from: "", to: nil
    remove_column :journal_pages, :favorite
  end
end
