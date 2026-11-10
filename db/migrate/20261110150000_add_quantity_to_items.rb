# How many of an item a character carries, counted up and down on the sheet.
class AddQuantityToItems < ActiveRecord::Migration[8.2]
  def change
    add_column :items, :quantity, :integer, default: 1, null: false
  end
end
