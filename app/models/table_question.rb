# A poll: a question the GM puts to the players (Share with the table, on the
# GM table), maybe with choices to pick from. (Images go to the table as a
# handout in the chat instead: Message, kind handout.) Each player asked
# gets a TableAnswer up front, empty until they answer. Only the GMs see the
# answers; each player sees just their own, and can change it until the GM
# closes the question.
#
# Players see it as a modal on any campaign page (table_questions/_frame, in
# the layout's permanent slot), updated like a roll call: a broadcast over
# [campaign, :live] points the frame at campaign_asked_question_path, so each
# player loads their own. The GM table's fold lists the questions, replaced
# live over [campaign, :questions] as answers come in.
class TableQuestion < ApplicationRecord
  MAX_LENGTH = 500
  MAX_CHOICES = 6
  CHOICE_LENGTH = 80
  RECENT = 8

  belongs_to :campaign
  include OutlivesItsAccount
  has_many :answers, -> { order(:id) }, class_name: "TableAnswer", inverse_of: :table_question, dependent: :delete_all

  # Who's asked: player memberships here, set when it's made.
  attr_accessor :asked

  scope :open, -> { where(closed_at: nil) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  normalizes :body, with: ->(body) { body.strip.presence }

  validates :body, presence: true, length: { maximum: MAX_LENGTH }
  validate :choices_fit
  validate :asked_by_a_gm, :asks_players, on: :create
  validate(on: :create) { campaign&.refuse_new_play(self) }

  after_create :create_answers
  after_create_commit -> { broadcast_prepend_later_to campaign, :questions, target: "table_questions", partial: "table_questions/question" }
  after_update_commit -> { broadcast_card }
  after_destroy_commit -> { broadcast_remove_to campaign, :questions }
  after_commit :broadcast_to_players

  # members: membership ids; only the campaign's players count.
  def self.ask!(campaign:, by:, members:, body:, choices: nil)
    create!(campaign: campaign, identity: by, body: body, choices: choices,
      asked: campaign.memberships.player.where(id: Array(members)).includes(:identity).to_a)
  end

  # The question waiting on this player, and their answer: the oldest they
  # haven't answered, else the newest they have (to change it). Never for a GM.
  def self.showing_for(campaign, membership)
    return if membership.nil? || membership.gm?

    answers = TableAnswer.joins(:table_question).merge(where(campaign: campaign).open).where(membership: membership).includes(:table_question)
    answers.where(answered_at: nil).order(:id).first || answers.order(id: :desc).first
  end

  # One per line, or a list; blanks and repeats dropped.
  def choices=(value)
    list = value.is_a?(String) ? value.lines : Array(value)
    super(list.map { _1.to_s.squish }.compact_blank.uniq)
  end

  def open?
    closed_at.nil?
  end

  def close!
    update!(closed_at: Time.current) if open?
  end

  def asked_by
    identity.display_name
  end

  def answered
    answers.select(&:answered?)
  end

  # A broadcast renders it in a job: viewer-agnostic, as only GMs see it.
  def broadcast_card
    broadcast_replace_later_to campaign, :questions, partial: "table_questions/question"
  end

  private
    def choices_fit
      errors.add(:choices, "can be #{MAX_CHOICES} at most") if choices.size > MAX_CHOICES
      errors.add(:choices, "must each be #{CHOICE_LENGTH} characters or fewer") if choices.any? { _1.length > CHOICE_LENGTH }
    end

    def asked_by_a_gm
      errors.add(:base, "Only the GM can ask the table") unless identity&.membership_in(campaign)&.gm?
    end

    def asks_players
      errors.add(:base, "Pick at least one player to ask") if asked.blank?
    end

    def create_answers
      asked.each { answers.create!(membership: _1, name: _1.identity.display_name) }
    end

    def broadcast_to_players
      Turbo::StreamsChannel.broadcast_update_later_to campaign, :live, target: campaign.question_slot_id,
        partial: "table_questions/frame", locals: { campaign: campaign, version: (Time.current.to_f * 1000).to_i }
    end
end
