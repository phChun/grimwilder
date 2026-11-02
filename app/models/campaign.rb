# A Grimwild campaign: the shared table a GM runs and players join. Campaign
# is the tenant boundary: campaign-owned records carry campaign_id, and
# controllers load them through Current.campaign.
class Campaign < ApplicationRecord
  include Archive, Hold, Blocking, Breaks, DowntimeActions, Reset, OptionalRules, CharacterSettings

  JOIN_CODE_LENGTH = 12

  has_many :memberships, dependent: :destroy
  has_many :identities, through: :memberships
  has_many :roll_calls, dependent: :delete_all
  has_many :rolls, dependent: :delete_all
  has_many :messages, dependent: :delete_all
  has_many :play_sessions, dependent: :destroy
  has_many :scenes
  has_many :scene_plans, dependent: :delete_all
  has_one :schedule, class_name: "Campaign::Schedule", dependent: :destroy
  has_many :game_dates, dependent: :delete_all
  has_many :pools, dependent: :destroy
  has_many :characters, dependent: :nullify
  # Up-for-grabs characters stay with the GM who held them, no longer offered.
  # (Prepended, so it runs before the nullify above unseats them.)
  before_destroy(prepend: true) { characters.up_for_grabs.update_all(up_for_grabs: false) }

  normalizes :name, :setting, :party_never, :group_arc, with: ->(value) { value.squish.presence }
  normalizes :pitch, with: ->(value) { value.strip.presence }

  validates :name, presence: true, length: { maximum: 80 }
  validates :pitch, length: { maximum: 200 }
  validates :setting, :party_never, :group_arc, length: { maximum: 80 }
  validates :join_code, presence: true, uniqueness: true

  before_validation :generate_join_code, on: :create
  # Everyone at the table sees suspense; pages update it in place, without a reload.
  after_update_commit -> { broadcast_replace_later_to self, :live, target: suspense_meter_id, partial: "campaigns/suspense_meter", locals: { campaign: self } },
    if: :saved_change_to_suspense?

  def self.create_with_gm!(name:, gm:)
    transaction do
      create!(name: name).tap { |campaign| campaign.memberships.create!(identity: gm, role: :gm) }
    end
  end

  def reset_join_code!
    self.join_code = nil
    generate_join_code
    save!
  end

  def gms
    identities.merge(Membership.gm)
  end

  # The party is (pg. 45): two concepts, cleaned and capped.
  def party_is=(value)
    list = value.is_a?(Hash) || value.is_a?(ActionController::Parameters) ? value.to_h.values : Array(value)
    super(list.map { _1.to_s.squish.first(40) }.compact_blank.first(2))
  end

  def pitched?
    [ pitch, setting, party_never, group_arc ].any?(&:present?) || party_is.any?
  end

  def current_session
    play_sessions.open.first
  end

  def current_scene
    scenes.open.first
  end

  # A boundary in the log ("Session 4 begins", "Rest"), which also refreshes everyone's table.
  def post_marker!(name, by:, text: nil, play_session: nil, scene: nil, level_ups: [])
    rolls.create!(kind: "marker", identity: by, name: name, play_session: play_session, scene: scene, question: text.to_s.strip.presence,
      sides: level_ups.map { { "character_id" => _1.id, "name" => _1.name, "level" => _1.level } }).tap { broadcast_table_refresh }
  end

  # Boundaries (a session starting, a rest) change what everyone's table shows,
  # and the live banner on every other campaign page. The banner has its own
  # stream so pages that don't morph never reload for it.
  def broadcast_table_refresh
    ActiveRecord.after_all_transactions_commit do
      broadcast_refresh_later_to(self, :table)
      broadcast_update_later_to(self, :live, target: live_banner_id, partial: "campaigns/live_banner", locals: { campaign: self })
    end
  end

  def live_banner_id
    ActionView::RecordIdentifier.dom_id(self, :live_banner)
  end

  # The roll call's frame, and the permanent slot around it (roll_calls/_frame).
  def roll_call_frame_id
    ActionView::RecordIdentifier.dom_id(self, :roll_call)
  end

  def roll_call_slot_id
    ActionView::RecordIdentifier.dom_id(self, :roll_call_slot)
  end

  def suspense_meter_id
    ActionView::RecordIdentifier.dom_id(self, :suspense)
  end

  private
    def generate_join_code
      self.join_code ||= loop do
        candidate = SecureRandom.base58(JOIN_CODE_LENGTH).scan(/.{4}/).join("-")
        break candidate unless self.class.exists?(join_code: candidate)
      end
    end
end
