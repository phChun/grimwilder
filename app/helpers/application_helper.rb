module ApplicationHelper
  # How long a failure toast (shared/_toast) stays up, unless held.
  FAILURE_TOAST_SECONDS = 10

  # Short words that stay lowercase inside a title ("Laws of the Land").
  TITLE_SMALL_WORDS = %w[ a an and as at but by for in nor of on or the to with ].freeze

  # "uncover the truth" -> "Uncover the Truth", "quick-witted" -> "Quick-Witted".
  # For showing the book's lowercase lists and what players typed from them;
  # what's stored doesn't change. Capitals already there are kept.
  def title_case(text)
    words = text.to_s.squish.split(" ")
    words.each_with_index.map do |word, index|
      if index.positive? && index < words.size - 1 && TITLE_SMALL_WORDS.include?(word.downcase)
        word.downcase
      else
        word.gsub(/(\A|-)(\p{Ll})/) { "#{$1}#{$2.upcase}" }
      end
    end.join(" ")
  end

  # The play toolkit's public tools. They're the header's tabs outside a
  # campaign, and always listed in the footer. `ready: false` items render as
  # "soon". Characters and campaigns need an account, so they aren't here; the
  # home page offers them once you're signed in.
  TOOLKIT_NAV = [
    { label: "Roll", path: :roll_path, ready: true },
    { label: "Crucibles", path: :crucibles_path, ready: true },
    { label: "Talents", path: :talents_path, ready: true }
  ].freeze

  def toolkit_nav
    TOOLKIT_NAV
  end

  # The campaign the page belongs to, for the header and live banner: the one
  # in the URL, or the campaign a sheet's character is seated in.
  def context_membership
    Current.membership || @membership
  end

  # The header's tabs inside a campaign: [label, path, current?]. Party and
  # Characters point at the campaign page's party section.
  def campaign_tabs(membership)
    campaign = membership.campaign
    on_campaign = controller_path == "campaigns" && action_name == "show"
    log = [ "Log", campaign_play_sessions_path(campaign), controller_path == "campaigns/play_sessions" ]

    if membership.gm?
      [
        [ "Campaign", campaign_path(campaign), on_campaign ],
        [ "Table", campaign_table_path(campaign), controller_path == "campaigns/tables" ],
        log
      ]
    else
      mine = membership.seated_character
      [
        [ "Campaign", campaign_path(campaign), on_campaign ],
        ([ "My character", character_path(mine), controller_path == "characters" && @character == mine ] if mine),
        log
      ].compact
    end
  end

  # The live banner shows on campaign pages other than the one it links to:
  # the GM table, or a player's own sheet.
  def live_banner?(membership)
    on_table = membership.gm? && controller_path == "campaigns/tables"
    on_own_sheet = controller_path == "characters" && @character&.campaign_id == membership.campaign_id && @character.owned_by?(Current.identity)
    !(on_table || on_own_sheet)
  end

  # One letter for a monogram or avatar.
  def initial(name)
    name.to_s.strip[/\p{L}|\p{N}/]&.upcase || "?"
  end
end
