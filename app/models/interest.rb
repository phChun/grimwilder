# Someone asking to try Grimwilder while sign-ups are closed (/interest):
# their email, whether they'd mostly GM or play, and a note. Admins see the
# list in /admin and can make an account from it. One per email: asking again
# updates it, so the form never says whether an address was already there.
class Interest < ApplicationRecord
  ROLES = { "gm" => "Mostly GM", "player" => "Mostly play", "both" => "Both" }.freeze
  NOTE_LIMIT = 500

  normalizes :email_address, with: ->(value) { value.strip.downcase }
  normalizes :note, with: ->(value) { value.strip.presence }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
  validates :role, inclusion: { in: ROLES.keys }, allow_blank: true
  validates :note, length: { maximum: NOTE_LIMIT }

  # Two at once for a new email: the second finds the first's row and updates it.
  def self.record!(email_address:, role: nil, note: nil)
    interest = find_or_initialize_by(email_address: normalize_value_for(:email_address, email_address.to_s))
    interest.update!(role: role.presence, note: note)
    interest
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def role_label
    ROLES[role]
  end

  def identity
    Identity.find_by(email_address: email_address)
  end
end
