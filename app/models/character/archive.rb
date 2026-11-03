# Putting a character away (archived_at): off the Characters page's main
# list, into Archived at its foot, and out of play until unarchived. It's
# housekeeping, not a story ending (Character::Farewell): a character still
# playing at a table leaves it first, so the party loses them; a fallen or
# retired one stays where it's remembered. Only the owner archives, and not
# while the GM holds them up for grabs.
module Character::Archive
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(archived_at: nil) }
    scope :unarchived, -> { where(archived_at: nil) }
  end

  def archived?
    archived_at.present?
  end

  def archive!(by:)
    raise ArgumentError, "#{name} is up for grabs; a player picks them first." if up_for_grabs?
    return if archived?

    transaction do
      seat!(nil, by: by) if active? && campaign
      update!(archived_at: Time.current)
    end
  end

  def unarchive!
    update!(archived_at: nil) if archived?
  end
end
