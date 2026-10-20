module ApplicationHelper
  # The play toolkit's tools. They're the header's tabs outside a campaign, and
  # always listed in the footer. `ready: false` items render as "soon".
  TOOLKIT_NAV = [
    { label: "Roll", path: :roll_path, ready: true },
    { label: "Crucibles", path: :crucibles_path, ready: true },
    { label: "Characters", path: :characters_path, ready: true },
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
        [ "Characters", campaign_path(campaign, anchor: "party"), false ],
        log
      ]
    else
      mine = membership.seated_character
      [
        [ "Campaign", campaign_path(campaign), on_campaign ],
        ([ "My character", character_path(mine), controller_path == "characters" && @character == mine ] if mine),
        [ "Party", campaign_path(campaign, anchor: "party"), false ],
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
