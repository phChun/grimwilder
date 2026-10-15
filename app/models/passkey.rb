# A WebAuthn credential (passkey) that can sign its identity in without email.
# `external_id` is the credential id; `public_key` verifies its signatures.
class Passkey < ApplicationRecord
  belongs_to :identity

  validates :external_id, :public_key, presence: true
  validates :external_id, uniqueness: true
  validates :name, presence: true, length: { maximum: 80 }

  def record_use!(sign_count)
    update!(sign_count: sign_count, last_used_at: Time.current)
  end
end
