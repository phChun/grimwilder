# A line of table chat. Messages and the roll log stay separate models; the
# table's rail merges them into one stream only in the view (TableFeed).
#
# Kinds, and who may send them:
# - narration: the GM, cutting to a scene ("Smoke pours through the slats…").
# - npc: the GM voicing someone, named in speaker_name.
# - in_character: a player as their active character seated here (the GM may
#   speak as any of them).
# - table_talk: anyone, as themselves.
# - handout: the GM shares an image (a map, a letter, a diagram) with the
#   whole table, with an optional caption in body. Shown only to the table
#   (Campaigns::Messages::ImagesController), and only as the raster types in
#   IMAGE_TYPES: never SVG, which can carry script.
# - whisper: private, between two people. A player's goes to the GM (no
#   recipient) or to another player; the GM's to a player. A player is picked
#   by their character (to_character: sets recipient and copies the
#   character's name into recipient_name). Only those two ever see it (the
#   GM's side is every GM; the GM doesn't see players' whispers to each
#   other): it's never broadcast to the table, and visible_to filters it from
#   everyone else's queries, the way hidden pools are.
#
# The speaker's name is copied in, so the chat still reads right after a
# rename or delete.
class Message < ApplicationRecord
  MAX_LENGTH = 500
  CHAT_SIZE = 40
  GM_KINDS = %w[ narration npc handout ].freeze
  IMAGE_TYPES = %w[ image/png image/jpeg image/webp image/gif ].freeze
  IMAGE_SIZE = 5.megabytes

  belongs_to :campaign
  belongs_to :identity
  belongs_to :character, optional: true
  belongs_to :recipient, class_name: "Identity", optional: true
  has_one_attached :image

  # The GM's whisper names a character; it reaches that character's player.
  attr_reader :to_character

  enum :kind, %w[ narration npc in_character table_talk whisper handout ].index_by(&:itself), default: "table_talk", validate: true

  normalizes :body, with: ->(body) { body.strip }
  normalizes :speaker_name, with: ->(name) { name.squish.presence }

  validates :name, presence: true
  validates :body, presence: true, unless: :handout?
  validates :body, length: { maximum: MAX_LENGTH }
  validate :image_fits
  validates :speaker_name, presence: true, length: { maximum: 60 }, if: :npc?
  validate :sender_may_speak_this_way
  validate(on: :create) { campaign&.refuse_new_play(self) }

  before_validation :copy_in_name

  # Whispers reach only the GM and the sender; everything else, the table.
  # The partial renders here, outside a request, so it must not use Current.
  after_create_commit :broadcast_to_table
  after_destroy_commit :broadcast_removal

  scope :visible_to, ->(membership) {
    if membership.nil? then where.not(kind: "whisper")
    elsif membership.gm?
      gms = membership.campaign.memberships.gm.select(:identity_id)
      where.not(kind: "whisper").or(where(kind: "whisper", recipient_id: nil)).or(where(kind: "whisper", identity_id: gms))
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

  # A handout shows in every view but Dice and the private ones, so a player
  # on Table talk still sees it arrive.
  def talk?
    table_talk? || handout?
  end

  # A whisper's two sides, for feed_controller.js to find a conversation's
  # lines: a player by their identity id, the GM as "gm".
  def from_side
    sent_by_gm? ? "gm" : identity_id.to_s if whisper?
  end

  def to_side
    recipient_id&.to_s || "gm" if whisper?
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

    # The type is what Active Storage found in the file itself, not its name.
    def image_fits
      if handout? && !image.attached?
        errors.add(:image, "is needed for a handout")
      elsif image.attached?
        errors.add(:image, "only goes on a handout") unless handout?
        errors.add(:image, "must be a PNG, JPEG, WebP or GIF") unless image.blob.content_type.in?(IMAGE_TYPES)
        errors.add(:image, "must be #{IMAGE_SIZE / 1.megabyte} MB or smaller") if image.blob.byte_size > IMAGE_SIZE
      end
    end

    def speaks_as_an_active_character(membership)
      if character.nil?
        errors.add(:character, "must be chosen to speak in character")
      elsif character.campaign_id != campaign_id || !character.active? || !(membership.gm? || character.identity_id == identity_id)
        errors.add(:character, "must be your active character at this table")
      end
    end

    def sent_by_gm?
      identity&.membership_in(campaign)&.gm?
    end

    # A player whispers to the GM (no recipient) or another player; the GM,
    # to a player. Players are picked by their active character here.
    def whispers_to_someone_allowed(membership)
      return if recipient.nil? && !membership.gm?

      if recipient.nil? || recipient == identity || recipient.membership_in(campaign)&.player? != true
        errors.add(:recipient, "must be another player at this table")
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
      [ ([ campaign, :gm ] if recipient.nil? || sent_by_gm?), *players.map { [ _1, :chat ] } ].compact
    end
end
