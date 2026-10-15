# A person, identified by email. Signs in with an emailed code or a passkey;
# there are no passwords.
class Identity < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :passkeys, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }
  normalizes :name, with: ->(value) { value.squish.presence }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 80 }
  validates :name, presence: true, on: :profile

  def self.find_or_create_for_sign_in!(email_address)
    find_or_create_by!(email_address: email_address)
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
end
