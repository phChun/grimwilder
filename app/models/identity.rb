# A person, identified by email. Signs in with an emailed code or a passkey;
# there are no passwords. Joins campaigns through memberships, as many as
# their plan allows (Identity::Plans).
class Identity < ApplicationRecord
  include Plans

  has_many :sessions, dependent: :destroy
  has_many :passkeys, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :campaigns, through: :memberships
  has_many :characters, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }
  normalizes :name, with: ->(value) { value.squish.presence }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 80 }
  validates :name, presence: true, on: :profile

  def self.find_or_create_for_sign_in!(email_address)
    find_or_create_by!(email_address: email_address)
  end

  # Sign-ups (config.x.signups_open, from ALLOW_SIGNUPS). While they're closed,
  # a new email only gets an account through a campaign's invite link.
  def self.signups_open?
    Rails.configuration.x.signups_open
  end

  def self.may_sign_in?(email_address, invited: false)
    signups_open? || invited || exists?(email_address: normalize_value_for(:email_address, email_address.to_s))
  end

  def display_name
    name.presence || email_address.split("@").first
  end

  def profile_complete?
    name.present?
  end

  def webauthn_user_handle!
    update!(webauthn_user_handle: WebAuthn.generate_user_id) if webauthn_user_handle.blank?
    webauthn_user_handle
  end

  def membership_in(campaign)
    memberships.find_by(campaign: campaign)
  end
end
