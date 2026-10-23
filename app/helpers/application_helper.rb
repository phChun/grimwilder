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
  # "soon". Characters and campaigns need an account, so they aren't here: the
  # header adds a Characters tab once you're signed in (characters_tab).
  TOOLKIT_NAV = [
    { label: "Roll", path: :roll_path, ready: true },
    { label: "Crucibles", path: :crucibles_path, ready: true },
    { label: "Talents", path: :talents_path, ready: true }
  ].freeze

  def toolkit_nav
    TOOLKIT_NAV
  end

  # Every signed-in person's own characters, the last tab in the header inside
  # a campaign or out: [label, path, current?]. A player's sheet in a campaign
  # is "My character" instead.
  # The placeholder for a text box with a datalist of the book's words: it takes
  # anything typed, or one of ours. prefix: what the box is for ("But not…").
  def type_or_select(prefix = nil)
    prefix ? "#{prefix} type one in or select from our list" : "Type one in or select from our list"
  end

  # First in both navs, signed in: every campaign you're at, or have been.
  def all_campaigns_tab
    [ "All campaigns", campaigns_path, controller_path == "campaigns" && action_name.in?(%w[ index create ]) ]
  end

  def characters_tab
    [ "Characters", characters_path, controller_path == "characters" && action_name.in?(%w[ index new create ]) ]
  end

  # The campaign the page belongs to, for the header and live banner: the one
  # in the URL, or the campaign a sheet's character is seated in.
  def context_membership
    Current.membership || @membership
  end

  # The header's tabs inside a campaign: [label, path, current?], starting
  # with All campaigns and then this one, by name (cut short if it's long). A
  # player with more than one character seated here gets "My characters" with
  # a menu of them instead of a path: [[name, path, current?], ...].
  def campaign_tabs(membership)
    campaign = membership.campaign
    this_one = [ tag.span(campaign.name, class: "tabs__name"), campaign_path(campaign), controller_path == "campaigns" && action_name == "show" ]
    log = [ "Log", campaign_play_sessions_path(campaign), controller_path == "campaigns/play_sessions" ]

    if membership.gm?
      [
        all_campaigns_tab,
        this_one,
        ([ "Table", campaign_table_path(campaign), controller_path == "campaigns/tables" ] unless campaign.done?),
        log
      ].compact
    else
      sheets = membership.seated_characters.map { [ _1.name, character_path(_1), controller_path == "characters" && @character == _1 ] }
      mine =
        case sheets.size
        when 0 then nil
        when 1 then [ "My character", sheets.first[1], sheets.first[2] ]
        else [ "My characters", sheets, sheets.any?(&:last) ]
        end
      [ all_campaigns_tab, this_one, mine, log ].compact
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
