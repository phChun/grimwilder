# A Grimwild campaign: the shared table a GM runs and players join. Campaign
# is the tenant boundary: campaign-owned records carry campaign_id, and
# controllers load them through Current.campaign.
class Campaign < ApplicationRecord
  JOIN_CODE_LENGTH = 12

  has_many :memberships, dependent: :destroy
  has_many :identities, through: :memberships
  has_many :rolls, dependent: :delete_all
  has_many :play_sessions, dependent: :destroy
  has_many :pools, dependent: :destroy
  has_many :characters, dependent: :nullify

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 80 }
  validates :join_code, presence: true, uniqueness: true

  before_validation :generate_join_code, on: :create

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

  def current_session
    play_sessions.open.first
  end

  # Boundaries (a session starting, a rest) change what everyone's table shows.
  def broadcast_table_refresh
    ActiveRecord.after_all_transactions_commit { broadcast_refresh_later_to(self, :table) }
  end

  private
    def generate_join_code
      self.join_code ||= loop do
        candidate = SecureRandom.base58(JOIN_CODE_LENGTH).scan(/.{4}/).join("-")
        break candidate unless self.class.exists?(join_code: candidate)
      end
    end
end
