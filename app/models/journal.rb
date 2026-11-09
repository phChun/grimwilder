# A player's journal at a campaign: their Membership's journal_pages, newest
# first, written when they like. The player writes it; the campaign's GMs may
# read it while it's shared (memberships.journal_shared, on by default), and
# may add pages of their own, which they always see and may lock so the
# player can only read them.
class Journal
  attr_reader :membership

  def initialize(membership)
    @membership = membership
  end

  def campaign
    membership.campaign
  end

  # Whether this person may open it: the player, or the campaign's GMs (who
  # see their own pages, and the player's while it's shared). A GM keeps none.
  def readable_by?(viewer)
    membership.player? && (viewer == membership || gm?(viewer))
  end

  # The pages this person may read, newest first.
  def pages_for(viewer)
    return JournalPage.none unless readable_by?(viewer)

    pages = membership.journal_pages.newest_first
    viewer == membership || membership.journal_shared? ? pages : pages.by_gm
  end

  # Whether this person may add a page: the player, or a GM.
  def writable_by?(viewer)
    readable_by?(viewer)
  end

  # The player's own pages and the GM's unlocked ones are theirs to change;
  # a GM's are the GMs'.
  def editable_by?(page, viewer)
    return false unless page.membership_id == membership.id && readable_by?(viewer)

    page.by_gm? ? gm?(viewer) || (viewer == membership && !page.locked?) : viewer == membership
  end

  # A new page by this person: the GM's may be locked.
  def write!(viewer, title:, body:, locked: false)
    membership.journal_pages.create!(title: title, body: body, by_gm: gm?(viewer), locked: gm?(viewer) && locked)
  end

  private
    def gm?(viewer)
      viewer&.gm? && viewer.campaign_id == membership.campaign_id
    end
end
