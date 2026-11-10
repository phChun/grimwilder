# A character's important items (Item), kept beside their arcana.
module Character::Items
  extend ActiveSupport::Concern

  included do
    has_many :items, dependent: :destroy
  end
end
