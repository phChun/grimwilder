class AddStoryAndQuarrelRolls < ActiveRecord::Migration[8.2]
  def change
    add_column :rolls, :question, :string # a story roll's question, or a quarrel's stakes
    add_column :rolls, :sides, :json, null: false, default: []
    add_column :rolls, :winner, :string # nil on a tied quarrel
  end
end
