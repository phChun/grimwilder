# An arcana's optional additions (pg. 42): heavy cost, unique reset,
# ritual ability, curse, sentient (Arcanum::ADDITIONS).
class AddAdditionsToArcana < ActiveRecord::Migration[8.2]
  def change
    add_column :arcana, :additions, :json, default: [], null: false
  end
end
