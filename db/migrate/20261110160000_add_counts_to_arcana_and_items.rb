# Arcana and items can keep a count (Countable): only those marked `counted`
# show − and + on the sheet.
class AddCountsToArcanaAndItems < ActiveRecord::Migration[8.2]
  def change
    add_column :items, :counted, :boolean, default: false, null: false
    add_column :arcana, :counted, :boolean, default: false, null: false
    add_column :arcana, :quantity, :integer, default: 1, null: false
  end
end
