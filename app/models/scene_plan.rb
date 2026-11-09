# A scene the GM prepares ahead of play: a title, notes, and maybe the
# question for a story roll as it opens, in a scene collection
# (SceneCollection) or loose. Starting a scene can pick one, straight away or
# filling in the form (Campaigns::ScenesController#new); once started from, it
# belongs to that scene and leaves the list of ones to play.
class ScenePlan < ApplicationRecord
  belongs_to :campaign
  belongs_to :scene, optional: true
  belongs_to :scene_collection, optional: true

  normalizes :title, :story_question, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :title, presence: true, length: { maximum: 120 }
  validates :story_question, length: { maximum: 200 }
  validates :notes, length: { maximum: 2000 }
  validate :collection_in_campaign

  scope :ordered, -> { order(:position, :created_at) }
  scope :unplayed, -> { where(scene_id: nil) }
  scope :played, -> { where.not(scene_id: nil) }
  scope :loose, -> { where(scene_collection_id: nil) }

  before_create { self.position = campaign.scene_plans.maximum(:position).to_i + 1 }

  def played?
    scene_id.present?
  end

  private
    def collection_in_campaign
      errors.add(:scene_collection, "isn't in this campaign") if scene_collection && scene_collection.campaign_id != campaign_id
    end
end
