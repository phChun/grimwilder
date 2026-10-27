# One roll at the table: an action or defense roll from a character sheet, a
# story roll, a quarrel, a montage, or a pool roll; a marker for a session or
# scene boundary; or a short note ("Tibbs enters a frenzy"). A campaign's rolls are its shared log, broadcast to everyone at
# the table as they land; rolls on hidden pools reach only the GM. Each is
# stamped with the session and scene that were going when it was made.
#
# Names are copied in when rolled, so the log still reads right after a
# character or pool is renamed or deleted.
class Roll < ApplicationRecord
  include Story, Quarrel, Montage, FollowUps

  belongs_to :campaign, optional: true
  belongs_to :identity
  belongs_to :character, optional: true
  belongs_to :pool, optional: true
  belongs_to :play_session, optional: true
  belongs_to :scene, optional: true
  has_one :roll_call, dependent: :nullify

  enum :kind, %w[ action defense story quarrel montage pool marker note ].index_by(&:itself), validate: true

  validates :name, presence: true
  validate(on: :create) { campaign&.refuse_new_play(self) }
  validates :question, presence: true, length: { maximum: 200 }, if: :note?
  validates :outcome, inclusion: { in: Grimwild::Dice::RESULTS }, if: -> { action? || defense? || story? || montage? }
  validates :outcome, inclusion: { in: Grimwild::Dice::RESULTS }, allow_nil: true, if: :pool? # power pools rolled as an action

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :visible_to, ->(membership) { membership&.gm? ? all : where(gm_only: false) }
  scope :table_log, ->(membership, limit: 50) { visible_to(membership).includes(:identity, :pool).recent.limit(limit) }

  before_validation :stamp_session, on: :create
  after_create_commit :broadcast_to_table, if: :campaign
  after_update_commit :broadcast_change_to_table, if: :campaign

  # A short line in the log, by someone at the table or about a character.
  # A done campaign's log stays as it was: a sheet can still change (moving the
  # character to a new table, marking them fallen), but nothing is noted there.
  def self.note!(campaign:, by:, text:, character: nil)
    return if campaign&.done?

    create!(campaign: campaign, identity: by, kind: "note", character: character,
      name: character&.name || by.display_name, question: text.to_s.squish.first(200))
  end

  # Players follow the open log; the GM also follows the GM-only one.
  def self.streams_for(campaign, membership)
    [ [ campaign, :rolls ], ([ campaign, :gm_rolls ] if membership&.gm?) ].compact
  end

  # The roller's own d6s plus any assist dice: together they set the result.
  def all_dice
    dice + assists.pluck("die")
  end

  def damage_thorns
    damage_reasons.size
  end

  def situational_thorns
    thorns.size - damage_thorns
  end

  def disaster?
    outcome == "disaster"
  end

  private
    def stamp_session
      self.play_session ||= campaign&.current_session
      self.scene ||= campaign&.current_scene if play_session&.open?
    end

    # Into the table's rail (TableFeed), after the newest line.
    def broadcast_to_table
      broadcast_append_later_to table_stream, target: "table_feed", partial: "rolls/feed_item", locals: { roll: self }
    end

    def broadcast_change_to_table
      broadcast_replace_later_to table_stream, partial: "rolls/feed_item", locals: { roll: self }
    end

    def table_stream
      [ campaign, (gm_only? ? :gm_rolls : :rolls) ]
    end
end
