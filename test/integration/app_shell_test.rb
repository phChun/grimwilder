require "test_helper"

class AppShellTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "outside a campaign the tabs are the toolkit's, and signed out there's a sign-in button" do
    get root_path
    assert_select ".app-header .brand .brand__name", "Grimwilder"
    assert_select ".app-header .brand .brand__beta", "Beta"
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", "Roll"
    assert_select ".app-header a.account--signin", "Sign in"
    assert_select ".app-header .reset-notice", 0
    assert_select ".tabs__link", text: "All campaigns", count: 0
    assert_select ".site-footer__tools a", "Crucibles"
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", 3
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", text: "Characters", count: 0
    assert_select ".site-footer__tools a", text: "Characters", count: 0
  end

  test "the home page's free tools need no account, and signed in the hero leads to your things" do
    get root_path
    assert_select "#tools-heading", "Free tools"
    assert_select ".home-cta__actions a.button--primary[href=?]", campaigns_path(anchor: "campaign-new"), "Start a campaign"
    assert_select ".tool-card[href=?]", talents_path
    assert_select ".tool-card", 3, "just the free tools"

    sign_in_as identities(:pip)
    get root_path
    assert_select ".home-cta__actions a[href=?]", characters_path
    assert_select ".tool-card", 3
  end

  test "signed in, every page's tabs start with all campaigns and end with your characters" do
    sign_in_as identities(:stranger)
    get root_path
    assert_select ".app-header .reset-notice", "While in beta, data may be reset any time"
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", 5
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link:first-child[href=?]", campaigns_path, "All campaigns"
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link[href=?]", characters_path, "Characters"

    get campaigns_path
    assert_select ".tabs__link[aria-current=page]", "All campaigns"

    get characters_path
    assert_select ".tabs__link[aria-current=page]", "Characters"
    assert_select ".site-footer__tools a", text: "Characters", count: 0
  end

  test "on a phone the tabs, feedback and account fold into the menu, with the same links" do
    identities(:gwen).update!(feedback_enabled: true)
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)

    row = css_select("nav.tabs .tabs__link").map { _1["href"] }
    menu = css_select(".nav-menu nav .nav-menu__link").map { _1["href"] }
    assert_equal row, menu
    assert_select ".nav-menu .nav-menu__link[aria-current=page]", @campaign.name
    assert_select ".nav-menu .nav-menu__links--account a[href^=?]", new_feedback_path, /Send feedback/
    assert_select ".nav-menu .nav-menu__links--account a[href=?]", profile_path, /Account · Gwen/

    sign_out
    get root_path
    assert_select ".nav-menu .nav-menu__links--account a[href=?]", new_session_path, "Sign in"
  end

  test "a player with two characters gets each sheet under My characters in the menu" do
    identities(:pip).characters.create!(name: "Moss", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign)
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".nav-menu .nav-menu__heading", "My characters"
    assert_select ".nav-menu .nav-menu__link--sub", 2
  end

  test "making a character needs an account" do
    get new_character_path
    assert_redirected_to new_session_path
  end

  test "the GM gets the campaign's tabs and an account button" do
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)

    assert_select "nav.tabs[aria-label=Campaign] .tabs__link", count: 6
    assert_select "nav.tabs[aria-label=Campaign] .tabs__link:first-child[href=?]", campaigns_path, "All campaigns"
    assert_select ".tabs__link[aria-current=page][href=?] .tabs__name", campaign_path(@campaign), @campaign.name
    assert_select ".tabs__link[href=?]", campaign_table_path(@campaign), "Table"
    assert_select ".tabs__link[href=?]", campaign_journals_path(@campaign), "Journals"
    assert_select ".tabs__link[href=?]", campaign_play_sessions_path(@campaign), "Log"
    assert_select ".tabs__link[href=?]", characters_path, "Characters"
    assert_select "a.account[aria-label=?]", "Account: Gwen", "G"
  end

  test "every page has the confirmation dialog that stands in for the browser's confirm()" do
    get root_path
    assert_select "dialog#confirm.confirm[data-controller=confirm][data-turbo-permanent]" do
      assert_select "[data-confirm-target=message]"
      assert_select "button[data-action='confirm#cancel'][data-confirm-target=cancelButton]", "Cancel"
      assert_select "button[data-action='confirm#accept'][data-confirm-target=acceptButton]"
    end
  end

  test "a player's tabs lead to their character, and the sheet marks it current" do
    sign_in_as identities(:pip)
    get character_path(characters(:tibbs))

    assert_select ".tabs__link[aria-current=page][href=?]", character_path(characters(:tibbs)), "My character"
    assert_select "nav.tabs[aria-label=Campaign] .tabs__link", count: 6
    assert_select ".tabs__link[href=?]", campaign_journal_path(@campaign, memberships(:pip_player)), "Journal"
    assert_select ".tabs__link", text: "Party", count: 0
  end

  test "a player with two characters seated picks which sheet to open from the tab" do
    tibbs = characters(:tibbs)
    moss = identities(:pip).characters.create!(name: "Moss", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign)
    identities(:pip).characters.create!(name: "Old Fen", path: "Fighter", brawn: 3, agility: 2, wits: 2, presence: 1, campaign: @campaign, status: "retired")
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select ".tabs__link", text: "My character", count: 0
    assert_select "details.tab-menu" do
      assert_select "summary.tabs__link:not(.tabs__link--current)", "My characters"
      assert_select ".tab-menu__menu a", 2, "only the ones still playing"
      assert_select ".tab-menu__menu a[href=?]", character_path(moss), "Moss"
      assert_select ".tab-menu__menu a[href=?]", character_path(tibbs), tibbs.name
    end

    get character_path(moss)
    assert_select "summary.tabs__link--current", "My characters"
    assert_select ".tab-menu__menu a[aria-current=page][href=?]", character_path(moss)
  end

    test "the live banner shows while a session is open, except on the page it links to" do
    get_banner = ->(path) { get path; css_select(".live-banner").first }

    sign_in_as identities(:gwen)
    assert_nil get_banner.(campaign_play_sessions_path(@campaign)), "no session yet"

    session = PlaySession.start!(@campaign, characters: [ characters(:tibbs), characters(:bram) ], by: identities(:gwen))
    Scene.start!(session, title: "The mill fire", by: identities(:gwen))

    banner = get_banner.(campaign_play_sessions_path(@campaign))
    assert_match "Live now", banner.text
    assert_match "Session 1 · Scene 1, The mill fire · 2 at the table", banner.text.squish
    assert_equal campaign_play_path(@campaign), banner["href"]
    assert get_banner.(campaign_path(@campaign)), "the campaign page isn't the table"
    assert_nil get_banner.(campaign_table_path(@campaign)), "the GM is already at the table"

    sign_out
    sign_in_as identities(:pip)
    assert get_banner.(campaign_path(@campaign)), "a player plays from their sheet"
    assert_nil get_banner.(character_path(characters(:tibbs))), "already on their sheet"
  end

  test "back to the table: the GM goes to the table, a player to their sheet" do
    sign_in_as identities(:gwen)
    get campaign_play_path(@campaign)
    assert_redirected_to campaign_table_path(@campaign)

    sign_out
    sign_in_as identities(:pip)
    get campaign_play_path(@campaign)
    assert_redirected_to character_path(characters(:tibbs))

    characters(:tibbs).update!(campaign: nil)
    get campaign_play_path(@campaign)
    assert_redirected_to campaign_path(@campaign)

    sign_out
    sign_in_as identities(:stranger)
    get campaign_play_path(@campaign)
    assert_response :not_found
  end

  test "boundaries update the live banner over its own stream" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :live ], count: 1 do
        PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: identities(:gwen))
      end
    end
  end

  test "players see suspense read-only in the sheet's rail, and it updates live" do
    @campaign.update!(suspense: 3)
    sign_in_as identities(:pip)
    get character_path(characters(:tibbs))

    assert_select ".table-rail__head ##{@campaign.suspense_meter_id}[aria-label=?] .suspense-meter__value", "Suspense: 3", "3"
    assert_select ".table-rail__head button", 0, "nothing to change it with"

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @campaign, :live ], count: 1 do
        @campaign.update!(suspense: 2)
      end
    end
  end

  test "only the GM changes suspense" do
    sign_in_as identities(:pip)
    patch campaign_suspense_path(@campaign), params: { by: 1 }
    assert_response :forbidden
    assert_equal 0, @campaign.reload.suspense
  end
end
