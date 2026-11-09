# A scene collection: prepared scenes (ScenePlan) grouped by where the
# players might go: the players head for the castle, so here are the castle's
# scenes. Each has a title and notes, which show on the GM table while one of
# its scenes is on. Starting a scene offers every collection's scenes.
# Removing a collection keeps its scenes, as standalone ones.
class SceneCollection < ApplicationRecord
  belongs_to :campaign
  has_many :scene_plans, dependent: :nullify

  normalizes :title, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :title, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2000 }

  scope :ordered, -> { order(:position, :created_at) }

  before_create { self.position = campaign.scene_collections.maximum(:position).to_i + 1 }

  def scenes_to_play
    scene_plans.unplayed.ordered
  end
end
