require "test_helper"

class AppShellTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "outside a campaign the tabs are the toolkit's, and signed out there's a sign-in button" do
    get root_path
    assert_select ".app-header .brand .brand__name", "Grimwilder"
    assert_select ".app-header .brand .brand__beta", "Beta"
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", "Roll"
    assert_select ".app-header a.account--signin", "Sign in"
    assert_select ".app-header .switcher", 0
    assert_select ".site-footer__tools a", "Crucibles"
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", 3
    assert_select "nav.tabs[aria-label=Toolkit] .tabs__link", text: "Characters", count: 0
    assert_select ".site-footer__tools a", text: "Characters", count: 0
  end

  test "the home page offers characters and pools once you're signed in" do
    get root_path
    assert_select "#tools-heading", "Free tools"
    assert_select ".hero__actions a.button--primary[href=?]", campaigns_path(anchor: "campaign-new"), "Start a campaign and build characters"
    assert_select ".tool-card[href=?]", talents_path
    assert_select ".tool-card[href=?]", characters_path, 0
    assert_select ".tool-card", 3, "signed out, just the free tools"

    sign_in_as identities(:pip)
    get root_path
    assert_select ".tool-card[href=?]", characters_path
    assert_select ".tool-card[href=?]", pools_path
    assert_select ".tool-card[href=?]", new_session_path, 0
  end

  test "making a character needs an account" do
    get new_character_path
    assert_redirected_to new_session_path
  end

  test "the GM gets the campaign's tabs, a switcher and an account button" do
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)

    assert_select "nav.tabs[aria-label=Campaign] .tabs__link", count: 4
    assert_select ".tabs__link[aria-current=page]", "Campaign"
    assert_select ".tabs__link[href=?]", campaign_table_path(@campaign), "Table"
    assert_select ".tabs__link", "Characters"
    assert_select ".tabs__link[href=?]", campaign_play_sessions_path(@campaign), "Log"
    assert_select ".switcher__name", @campaign.name
    assert_select ".switcher__menu a[aria-current=page]", /#{@campaign.name}/
    assert_select "a.account[aria-label=?]", "Account: Gwen", "G"
  end

  test "a player's tabs lead to their character, and the sheet marks it current" do
    sign_in_as identities(:pip)
    get character_path(characters(:tibbs))

    assert_select ".tabs__link[aria-current=page][href=?]", character_path(characters(:tibbs)), "My character"
    assert_select ".tabs__link", "Party"
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
