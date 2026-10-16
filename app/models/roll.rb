# One roll at the table: an action or defense roll from a character sheet, or
# a pool roll. A campaign's rolls are its shared log, broadcast to everyone at
# the table as they land; rolls on hidden pools reach only the GM.
#
# Names are copied in when rolled, so the log still reads right after a
# character or pool is renamed or deleted.
class Roll < ApplicationRecord
  belongs_to :campaign, optional: true
  belongs_to :identity
  belongs_to :character, optional: true
  belongs_to :pool, optional: true

  enum :kind, %w[ action defense pool ].index_by(&:itself), validate: true

  validates :name, presence: true
  validates :outcome, inclusion: { in: Grimwild::Dice::RESULTS }, unless: :pool?

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :visible_to, ->(membership) { membership&.gm? ? all : where(gm_only: false) }

  after_create_commit :broadcast_to_table, if: :campaign
  after_update_commit :broadcast_change_to_table, if: :campaign

  # Players follow the open log; the GM also follows the GM-only one.
  def self.streams_for(campaign, membership)
    [ [ campaign, :rolls ], ([ campaign, :gm_rolls ] if membership&.gm?) ].compact
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
