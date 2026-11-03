# A scene the GM prepares ahead of play: a title, notes, and maybe an
# opening story roll (a question and odds), in a block (SceneBlock) or loose.
# Starting a scene can pick one, straight away or filling in the form
# (Campaigns::ScenesController#new); once started from, it belongs to that
# scene and leaves the list of ones to play.
class ScenePlan < ApplicationRecord
  belongs_to :campaign
  belongs_to :scene, optional: true
  belongs_to :scene_block, optional: true

  normalizes :title, :opening_question, with: ->(value) { value.squish.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :title, presence: true, length: { maximum: 120 }
  validates :opening_question, length: { maximum: 200 }
  validates :notes, length: { maximum: 2000 }
  validates :opening_odds, inclusion: { in: ->(_) { Roll::ODDS.keys } }, allow_nil: true
  validate :block_in_campaign

  scope :ordered, -> { order(:position, :created_at) }
  scope :unplayed, -> { where(scene_id: nil) }
  scope :played, -> { where.not(scene_id: nil) }
  scope :loose, -> { where(scene_block_id: nil) }

  before_create { self.position = campaign.scene_plans.maximum(:position).to_i + 1 }

  def opening?
    opening_odds.present?
  end

  def played?
    scene_id.present?
  end

  # Roll.story! arguments for its opening, when it's started as written:
  # for no one in particular, with no thorns.
  def opening_args
    { character: nil, spend_spark: 0, question: opening_question, odds: opening_odds, thorns: 0 } if opening?
  end

  private
    def block_in_campaign
      errors.add(:scene_block, "isn't in this campaign") if scene_block && scene_block.campaign_id != campaign_id
    end
end
