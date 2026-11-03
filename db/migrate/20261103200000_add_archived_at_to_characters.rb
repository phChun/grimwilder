class AddArchivedAtToCharacters < ActiveRecord::Migration[8.2]
  def change
    add_column :characters, :archived_at, :datetime
  end
end
