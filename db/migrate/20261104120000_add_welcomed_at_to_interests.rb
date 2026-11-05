class AddWelcomedAtToInterests < ActiveRecord::Migration[8.2]
  def change
    add_column :interests, :welcomed_at, :datetime
  end
end
