# One stretch of action within a session (pg. 95). It opens in the middle of
# things, with a story roll if the setup is unclear, and closes with a montage
# once it has served its purpose. Ending it can clear "clears after scene"
# conditions (pg. 29) from the characters there.
class Scene < ApplicationRecord
  belongs_to :play_session
  belongs_to :campaign
  belongs_to :opening_roll, class_name: "Roll", optional: true
  belongs_to :closing_roll, class_name: "Roll", optional: true
  has_many :rolls, dependent: :nullify

  normalizes :title, with: ->(value) { value.squish }

  validates :title, presence: true, length: { maximum: 120 }
  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :play_session_id }
  validate :one_open_per_session, on: :create

  scope :ordered, -> { order(:number) }
  scope :open, -> { where(ended_at: nil) }

  # opening: story roll arguments (Roll.story!) to open with, or nil.
  def self.start!(session, title:, by:, opening: nil)
    raise ArgumentError, "#{session.title} has ended." unless session.open?
    raise ArgumentError, "#{session.current_scene.heading} is still going." if session.current_scene

    transaction do
      scene = session.scenes.create!(campaign: session.campaign, number: session.scenes.maximum(:number).to_i + 1,
        title: title, started_at: Time.current)
      session.post_marker!(scene.heading, by: by, scene: scene)
      scene.update!(opening_roll: Roll.story!(campaign: session.campaign, by: by, **opening)) if opening
      scene
    end
  end

  def heading
    "#{play_session.title} · Scene #{number}: #{title}"
  end

  def open?
    ended_at.nil?
  end

  # Each present character's "clears after scene" conditions, as [character, index, condition].
  def lingering_conditions
    play_session.characters.ordered.flat_map do |character|
      character.scene_conditions.map { |index, condition| [ character, index, condition ] }
    end
  end

  # clear: "character_id:index" for each scene condition to clear (the end form
  # ticks them all by default).
  def end!(by:, clear: [], notes: nil, closing_roll: nil)
    raise ArgumentError, "Scene #{number} has already ended." unless open?
    raise ArgumentError, "That closing roll isn't a montage from this scene." if closing_roll && !(closing_roll.montage? && closing_roll.scene_id == id)

    transaction do
      cleared = clear_conditions(clear)
      update!(ended_at: Time.current, notes: notes.to_s.strip.presence, closing_roll: closing_roll)
      play_session.post_marker!("Scene #{number} ends", by: by, scene: self,
        text: [ notes.to_s.strip.presence, *cleared.map { |name, condition| "#{name}: #{condition} cleared." } ].compact.join("\n"))
    end
  end

  private
    def clear_conditions(picks)
      chosen = Array(picks).map { _1.to_s.split(":", 2) }.group_by(&:first).transform_values { |pairs| pairs.map { _2.to_i } }

      play_session.characters.flat_map do |character|
        indexes = chosen.fetch(character.id.to_s, []) & character.scene_conditions.map(&:first)
        names = indexes.map { character.conditions[_1]["name"] }
        character.clear_conditions!(indexes) if indexes.any?
        names.map { [ character.name, _1 ] }
      end
    end

    def one_open_per_session
      errors.add(:base, "#{play_session.title} already has a scene going") if open? && play_session&.scenes&.open&.exists?
    end
end
