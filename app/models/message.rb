# A line of table chat. Messages and the roll log stay separate models; the
# table's rail merges them into one stream only in the view (TableFeed).
#
# Kinds, and who may send them:
# - narration: the GM, cutting to a scene ("Smoke pours through the slats…").
# - npc: the GM voicing someone, named in speaker_name.
# - in_character: a player as their active character seated here (the GM may
#   speak as any of them).
# - table_talk: anyone, as themselves.
# - whisper: private. A player's goes to the GM; the GM's goes to one player,
#   picked by their character (to_character: sets recipient and copies the
#   character's name into recipient_name). Only the sender, the recipient and
#   the GM ever see it: it's never broadcast to the table, and visible_to
#   filters it from every other player-facing query, the way hidden pools are.
#
# The speaker's name is copied in, so the chat still reads right after a
# rename or delete.
class Message < ApplicationRecord
  MAX_LENGTH = 500
  CHAT_SIZE = 40
  GM_KINDS = %w[ narration npc ].freeze

  belongs_to :campaign
  belongs_to :identity
  belongs_to :character, optional: true
  belongs_to :recipient, class_name: "Identity", optional: true

  # The GM's whisper names a character; it reaches that character's player.
  attr_reader :to_character

  enum :kind, %w[ narration npc in_character table_talk whisper ].index_by(&:itself), default: "table_talk", validate: true

  normalizes :body, with: ->(body) { body.strip }
  normalizes :speaker_name, with: ->(name) { name.squish.presence }

  validates :name, presence: true
  validates :body, presence: true, length: { maximum: MAX_LENGTH }
  validates :speaker_name, presence: true, length: { maximum: 60 }, if: :npc?
  validate :sender_may_speak_this_way
  validate(on: :create) { campaign&.refuse_new_play(self) }

  before_validation :copy_in_name

  # Whispers reach only the GM and the sender; everything else, the table.
  # The partial renders here, outside a request, so it must not use Current.
  after_create_commit :broadcast_to_table
  after_destroy_commit :broadcast_removal

  scope :visible_to, ->(membership) {
    if membership&.gm? then all
    elsif membership.nil? then where.not(kind: "whisper")
    else where.not(kind: "whisper").or(where(kind: "whisper", identity_id: membership.identity_id)).or(where(kind: "whisper", recipient_id: membership.identity_id))
    end
  }

  # The newest messages this member may see, oldest first, the way a chat reads.
  def self.chat_for(campaign, membership, limit: CHAT_SIZE)
    where(campaign: campaign).visible_to(membership).includes(:identity, :character).order(created_at: :desc, id: :desc).limit(limit).reverse
  end

  # The streams a member's rail follows: the table, plus the GM's stream for
  # whispers, or a player's own for theirs (sent or received).
  def self.streams_for(campaign, membership)
    [ [ campaign, :chat ], (membership&.gm? ? [ campaign, :gm ] : [ membership, :chat ]) ].compact
  end

  def story?
    !whisper? && !table_talk?
  end

  def to_character=(character)
    @to_character = character
    self.recipient = character&.identity
    self.recipient_name = character&.short_name
  end

  private
    def copy_in_name
      self.name =
        if npc? then speaker_name
        elsif in_character? then character&.name
        else identity&.display_name
        end
    end

    def sender_may_speak_this_way
      membership = identity&.membership_in(campaign) if campaign

      if membership.nil?
        errors.add(:base, "Only people at this table can talk here")
      elsif GM_KINDS.include?(kind) && !membership.gm?
        errors.add(:kind, "#{kind.humanize.downcase} is the GM's")
      elsif whisper?
        whispers_to_someone_allowed(membership)
      elsif in_character?
        speaks_as_an_active_character(membership)
      elsif character
        errors.add(:character, "only speaks in character")
      end
    end

    def speaks_as_an_active_character(membership)
      if character.nil?
        errors.add(:character, "must be chosen to speak in character")
      elsif character.campaign_id != campaign_id || !character.active? || !(membership.gm? || character.identity_id == identity_id)
        errors.add(:character, "must be your active character at this table")
      end
    end

    # A player whispers to the GM only; the GM, to a player at this table by
    # their active character.
    def whispers_to_someone_allowed(membership)
      if !membership.gm?
        errors.add(:recipient, "must be the GM") if recipient
      elsif recipient.nil? || recipient.membership_in(campaign)&.player? != true
        errors.add(:recipient, "must be a player at this table")
      elsif to_character && (to_character.campaign_id != campaign_id || !to_character.active?)
        errors.add(:recipient, "must be an active character at this table")
      end
    end

    def broadcast_to_table
      table_streams.each { broadcast_append_to _1, target: "table_feed", partial: "messages/message", locals: { message: self } }
    end

    def broadcast_removal
      table_streams.each { broadcast_remove_to _1 }
    end

    def table_streams
      return [ [ campaign, :chat ] ] unless whisper?

      players = [ identity, recipient ].compact.filter_map { _1.membership_in(campaign) }.reject(&:gm?)
      [ [ campaign, :gm ], *players.map { [ _1, :chat ] } ]
    end
end
