# For what an account leaves at a table: rolls, chat, roll calls and polls.
# When an admin removes the account (Identity::Removal) these stay, with
# identity_id nil, and read as Identity.removed ("Removed account"), so views
# and checks need no nil handling. New ones still need an account.
module OutlivesItsAccount
  extend ActiveSupport::Concern

  included do
    belongs_to :identity, optional: true
    validates :identity, presence: true, on: :create
  end

  def identity
    super || (Identity.removed unless new_record?)
  end
end
