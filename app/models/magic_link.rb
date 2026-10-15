# A short-lived sign-in code emailed to an address. It is tied to the email
# address, not to an Identity, so asking for a code never creates an account
# and never reveals whether one exists; the Identity is found or created only
# when the code is redeemed.
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :code, presence: true, uniqueness: true

  before_validation :generate_code, :set_expiration, on: :create

  scope :active, -> { where(expires_at: Time.current..) }
  scope :stale, -> { where(expires_at: ...Time.current) }

  class << self
    # Returns the redeemed link (now destroyed) or nil.
    def consume(code, email_address:)
      link = active.find_by(code: Code.sanitize(code))
      return unless link
      return unless ActiveSupport::SecurityUtils.secure_compare(link.email_address, email_address.to_s.strip.downcase)

      link.destroy!
    end

    def cleanup
      stale.delete_all
    end
  end

  private
    def generate_code
      self.code ||= loop do
        candidate = Code.generate(CODE_LENGTH)
        break candidate unless self.class.exists?(code: candidate)
      end
    end

    def set_expiration
      self.expires_at ||= EXPIRATION_TIME.from_now
    end
end
