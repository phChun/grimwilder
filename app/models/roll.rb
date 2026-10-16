# One roll at the table: an action or defense roll from a character sheet, a
# story roll, a quarrel, a montage, or a pool roll; or a marker for a session
# boundary. A campaign's rolls are its shared log, broadcast to everyone at
# the table as they land; rolls on hidden pools reach only the GM. Each is
# stamped with the session that was going when it was made.
#
# Names are copied in when rolled, so the log still reads right after a
# character or pool is renamed or deleted.
class Roll < ApplicationRecord
  include Story, Quarrel, Montage

  belongs_to :campaign, optional: true
  belongs_to :identity
  belongs_to :character, optional: true
  belongs_to :pool, optional: true
  belongs_to :play_session, optional: true

  enum :kind, %w[ action defense story quarrel montage pool marker ].index_by(&:itself), validate: true

  validates :name, presence: true
  validates :outcome, inclusion: { in: Grimwild::Dice::RESULTS }, if: -> { action? || defense? || story? || montage? }
  validates :outcome, inclusion: { in: Grimwild::Dice::RESULTS }, allow_nil: true, if: :pool? # power pools rolled as an action

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :visible_to, ->(membership) { membership&.gm? ? all : where(gm_only: false) }
  scope :table_log, ->(membership, limit: 50) { visible_to(membership).includes(:identity, :pool).recent.limit(limit) }

  before_validation :stamp_session, on: :create
  after_create_commit :broadcast_to_table, if: :campaign
  after_update_commit :broadcast_change_to_table, if: :campaign

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
    end

    def broadcast_to_table
      broadcast_prepend_later_to table_stream, target: "roll_log", partial: "rolls/roll", locals: { roll: self }
    end

    def broadcast_change_to_table
      broadcast_replace_later_to table_stream, partial: "rolls/roll", locals: { roll: self }
    end

    def table_stream
      [ campaign, (gm_only? ? :gm_rolls : :rolls) ]
    end
end
