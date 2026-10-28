# One sign-in, remembered by the signed `session_token` cookie. It lasts
# LIFETIME from signing in, then the person signs in again (code or passkey).
class Session < ApplicationRecord
  LIFETIME = 6.hours

  belongs_to :identity

  scope :expired, -> { where(created_at: ...LIFETIME.ago) }

  # The live session for a cookie's token, or nil once it's past LIFETIME.
  def self.resume(token)
    find_signed(token)&.then { _1 unless _1.expired? }
  end

  # Expired rows go hourly (config/recurring.yml).
  def self.cleanup
    expired.delete_all
  end

  def expired?
    created_at <= LIFETIME.ago
  end

  def expires_at
    created_at + LIFETIME
  end
end
