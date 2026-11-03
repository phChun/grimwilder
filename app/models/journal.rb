# A player's journal at a campaign (their Membership's journal_entries): a page
# for each session, and one for each stretch between sessions, newest first.
# The player writes it; the campaign's GMs may read it while it's shared
# (memberships.journal_shared, on by default).
class Journal
  Page = Data.define(:session_number, :between, :entry, :current) do
    # "session-4", "after-4" or "before": the page's id in its URL.
    def key
      if !between then "session-#{session_number}"
      elsif session_number.zero? then "before"
      else "after-#{session_number}"
      end
    end

    def title
      if !between then "Session #{session_number}"
      elsif session_number.zero? then "Before Session 1"
      else "After Session #{session_number}"
      end
    end

    def body
      entry&.body
    end

    def written?
      entry.present?
    end
  end

  attr_reader :membership

  def initialize(membership)
    @membership = membership
  end

  def campaign
    membership.campaign
  end

  # Whether this person may read it: the player, or a GM while it's shared.
  def readable_by?(viewer)
    viewer == membership || (viewer&.gm? && viewer.campaign_id == membership.campaign_id && membership.journal_shared?)
  end

  def writable_by?(viewer)
    viewer == membership && membership.player?
  end

  # Every page, newest first: each session, and between them only the ones
  # written or happening now. written_only: the ones with words (for the GM).
  def pages(written_only: false)
    entries = JournalEntry.where(membership: membership).index_by { [ _1.session_number, _1.between ] }
    now = current_key
    keys = campaign.play_sessions.maximum(:number).to_i.downto(0).flat_map { |number| [ [ number, true ], [ number, false ] ] }
      .select { |number, between| between ? (entries.key?([ number, true ]) || now == [ number, true ]) : number.positive? }

    list = keys.map { |number, between| Page.new(number, between, entries[[ number, between ]], now == [ number, between ]) }
    written_only ? list.select(&:written?) : list
  end

  # The page being lived now: the session going, or the stretch since the last.
  def current_page
    pages.find(&:current)
  end

  # A page by its key, listed or not (a stretch between sessions nobody wrote
  # in yet), or nil for one past the campaign's sessions.
  def page(key)
    number, between =
      case key.to_s
      when "before" then [ 0, true ]
      when /\Asession-(\d+)\z/ then [ $1.to_i, false ]
      when /\Aafter-(\d+)\z/ then [ $1.to_i, true ]
      end
    return unless number && (between || number.positive?) && number <= campaign.play_sessions.maximum(:number).to_i

    entry = JournalEntry.find_by(membership: membership, session_number: number, between: between)
    Page.new(number, between, entry, current_key == [ number, between ])
  end

  # Writes (or, with a blank body, clears) a page.
  def write!(page, body)
    entry = membership.journal_entries.find_or_initialize_by(session_number: page.session_number, between: page.between)
    if body.to_s.strip.empty?
      entry.destroy! if entry.persisted?
    else
      entry.update!(body: body)
    end
  end

  private
    def current_key
      if (session = campaign.current_session) then [ session.number, false ]
      else [ campaign.play_sessions.maximum(:number).to_i, true ]
      end
    end
end
