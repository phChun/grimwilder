# A block of prepared scenes (ScenePlan), grouped by where the players might
# go: the players head for the castle, so here are the castle's scenes. Each
# has a title and notes. A session can say which block it's playing
# (PlaySession#scene_block), which puts its scenes first when a scene starts;
# any scene still to play can be pulled into any session all the same.
# Removing a block keeps its scenes, out of any block.
class SceneBlock < ApplicationRecord
  belongs_to :campaign
  has_many :scene_plans, dependent: :nullify
  has_many :play_sessions, dependent: :nullify

  normalizes :title, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :title, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 2000 }

  scope :ordered, -> { order(:position, :created_at) }

  before_create { self.position = campaign.scene_blocks.maximum(:position).to_i + 1 }

  def scenes_to_play
    scene_plans.unplayed.ordered
  end
end
