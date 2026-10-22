# One sitting of a campaign (pg. 31). Called PlaySession because Session is
# the sign-in session; the UI just says "Session".
#
# Starting one is the pre-session: each character present resets thread and
# takes spark, and the GM takes suspense (none of that before session 1).
# Ending one gives everyone present 1 XP, or 2 for a standout session.
class PlaySession < ApplicationRecord
  belongs_to :campaign
  has_and_belongs_to_many :characters, join_table: :play_session_characters
  has_many :rolls, dependent: :nullify
  has_many :scenes, dependent: :destroy

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :campaign_id }
  validate :one_open_per_campaign, on: :create

  scope :ordered, -> { order(:number) }
  scope :open, -> { where(ended_at: nil) }
  scope :ended, -> { where.not(ended_at: nil) }

  def self.start!(campaign, characters:, by:, recap: nil)
    raise ArgumentError, "#{campaign.current_session.title} is still going." if campaign.current_session
    raise ArgumentError, "Everyone here must be seated in #{campaign.name}." unless characters.all? { _1.campaign_id == campaign.id }

    transaction do
      number = campaign.play_sessions.maximum(:number).to_i + 1
      session = campaign.play_sessions.create!(number: number, started_at: Time.current, characters: characters,
        recap: (recap.to_s.strip.presence unless number == 1))

      characters.each { _1.start_session!(first: session.first?) }
      campaign.increment!(:suspense) unless session.first?
      session.post_marker!("#{session.title} begins", by: by, text: session.recap)
      session
    end
  end

  def title
    "Session #{number}"
  end

  def first?
    number == 1
  end

  def open?
    ended_at.nil?
  end

  def current_scene
    scenes.open.first
  end

  def previous
    campaign.play_sessions.where(number: ...number).order(:number).last
  end

  # Level-ups recorded when the session ended: [{ "name", "level", "character_id" }].
  def level_ups
    rolls.marker.where(name: "#{title} ends").last&.sides || []
  end

  # Closes any open scene first, clearing the scene conditions picked (see
  # Scene#end!). Returns the characters who reached a new level.
  def end!(by:, standout: false, notes: nil, clear: [])
    raise ArgumentError, "#{title} has already ended." unless open?

    transaction do
      current_scene&.end!(by: by, clear: clear)
      update!(ended_at: Time.current, standout: standout, notes: notes.to_s.strip.presence)
      levelled = characters.select { |character| Array.new(standout ? 2 : 1) { character.gain_xp! }.any? }
      post_marker!("#{title} ends", by: by, text: notes, level_ups: levelled)
      levelled
    end
  end

  def post_marker!(name, **options)
    campaign.post_marker!(name, play_session: self, **options)
  end

  private
    def one_open_per_campaign
      errors.add(:base, "#{campaign.name} already has a session going") if open? && campaign&.play_sessions&.open&.exists?
    end
end
