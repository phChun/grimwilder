# A scene the GM prepares ahead of play: a title, notes, and maybe an
# opening story roll (a question and odds). Starting a scene can pick one,
# which fills in the form (Campaigns::ScenesController#new); once started
# from, it belongs to that scene and leaves the list of ones to play.
class ScenePlan < ApplicationRecord
  belongs_to :campaign
  belongs_to :scene, optional: true

  normalizes :title, :opening_question, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :title, presence: true, length: { maximum: 120 }
  validates :opening_question, length: { maximum: 200 }
  validates :notes, length: { maximum: 2000 }
  validates :opening_odds, inclusion: { in: ->(_) { Roll::ODDS.keys } }, allow_nil: true

  scope :ordered, -> { order(:position, :created_at) }
  scope :unplayed, -> { where(scene_id: nil) }
  scope :played, -> { where.not(scene_id: nil) }

  before_create { self.position = campaign.scene_plans.maximum(:position).to_i + 1 }

  def opening?
    opening_odds.present?
  end

  def played?
    scene_id.present?
  end
end
