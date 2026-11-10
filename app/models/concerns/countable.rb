# Arcana and items the sheet keeps a count of: three healing potions, fifty
# feet of rope. Only those marked `counted` show their count, with − and +.
module Countable
  extend ActiveSupport::Concern

  MAX_QUANTITY = 999

  included do
    validates :quantity, numericality: { only_integer: true, in: 0..MAX_QUANTITY }
  end

  # One more (by: 1) or one fewer (by: -1), never below none.
  def count_by!(by)
    update!(quantity: (quantity + by).clamp(0, MAX_QUANTITY))
  end
end
