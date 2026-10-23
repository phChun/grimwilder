require "test_helper"

# The campaign page (campaigns#show): the pitch, the party, "Previously on…",
# and a side column with the pools, who's here and kept crucibles. Players
# also roll pools and story rolls here and follow the log.
class CampaignPageTest < ActionDispatch::IntegrationTest
  setup { @campaign = campaigns(:bramblewood) }

  test "the GM's hero: the pitch, its facts, and the way to the table and the invite link" do
    @campaign.update!(pitch: "Toll-roads and a quietly failing accord.", party_is: [ "Wardens", "Outsiders" ], party_never: "Mercenaries",
      group_arc: "uncover the truth", setting: "The Bramble Marches")
    sign_in_as identities(:gwen)

    get campaign_path(@campaign)
    assert_select ".campaign-hero .eyebrow", "Campaign · You're the GM"
    assert_select "h1.campaign-hero__title", @campaign.name
    assert_select ".campaign-hero__pitch", "Toll-roads and a quietly failing accord."
    assert_select ".campaign-hero__facts dd", "Wardens, Outsiders"
    assert_select ".campaign-hero__facts dd", "Mercenaries"
    assert_select ".campaign-hero__facts dd", "Uncover the Truth"
    assert_select ".campaign-hero__facts dd", "The Bramble Marches"
    assert_select ".campaign-actions__row a.button--primary[href=?]", campaign_table_path(@campaign), "Open the GM table"
    assert_select ".campaign-actions__row button[data-clipboard-text-value=?]", join_url(@campaign.join_code), text: /Copy invite link/
    assert_select ".campaign-actions__row form[action=?] button", campaign_join_code_path(@campaign), "Reset link"
  end

  test "a GM with no pitch yet is asked for one; a player just gets their character" do
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)
    assert_select ".campaign-hero__pitch--empty a[href=?]", edit_campaign_path(@campaign)
    assert_select ".campaign-hero__facts", 0

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".campaign-hero .eyebrow", "Campaign · Playing Tibbs"
    assert_select ".campaign-hero__pitch", 0
    assert_select ".campaign-actions__row a.button--primary[href=?]", character_path(characters(:tibbs)), "Open my character"
    assert_select ".campaign-actions__row button", 0, "no invite link for players"
  end

  test "a player with two characters here picks which to open" do
    moss = identities(:pip).characters.create!(name: "Moss", path: "Druid", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: @campaign)
    sign_in_as identities(:pip)
    get campaign_path(@campaign)

    assert_select ".eyebrow", /Playing Tibbs and Moss/
    assert_select ".campaign-actions__row a.button--primary", 0
    assert_select ".campaign-actions__row details.go-menu" do
      assert_select "summary.button--primary", /Open my character/
      assert_select ".go-menu__item", 2
      assert_select ".go-menu__item[href=?]", character_path(moss), /Moss\s+Druid · level 1/
      assert_select ".go-menu__item[href=?]", character_path(characters(:tibbs))
    end
  end

  test "the party: a card per active character, a dashed one for a member still making theirs, and the fallen and retired below" do
    characters(:tibbs).update!(bloodied: true, marked_agility: true, conditions: [ "4d poisoned" ])
    characters(:bram).update!(status: "fallen", farewell: "Held the bridge.")
    @campaign.memberships.create!(identity: identities(:stranger), role: :player)
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    tibbs = "#party .hero-card:has(a[href='#{character_path(characters(:tibbs))}'])"
    assert_select "#{tibbs} .hero-card__name", "Tibbs"
    assert_select "#{tibbs} .hero-card__meta", "Rogue 1 · played by Pip"
    assert_select "#{tibbs} .pips--spark[aria-label=?]", "1 of 2 spark"
    assert_select "#{tibbs} .stat-tile", 4
    assert_select "#{tibbs} .stat-tile--marked .stat-tile__value", "3"
    assert_select "#{tibbs} .stat-tile--marked abbr[title=?]", "Agility (marked)"
    assert_select "#{tibbs} .hero-card__harm", "Bloodied · Agility marked · 4d poisoned"

    assert_select "#party .hero-card--empty .hero-card__name", "Stranger joined"
    assert_select "#party .hero-card", 2, "Tibbs and Stranger; Bram has fallen"
    assert_select "#fallen-and-retired .farewell-card--fallen" do
      assert_select ".farewell-card__status", /\AFallen · /
      assert_select "a.farewell-card__name[href=?]", character_path(characters(:bram)), "Bram"
      assert_select ".farewell-card__meta", "Fighter 1 · played by Gwen"
      assert_select ".farewell-card__words", "“Held the bridge.”"
    end
  end

  test "previously on: the last session's scenes and outcomes, and older sessions" do
    gwen = identities(:gwen)
    first = PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: gwen)
    first.end!(by: gwen)
    second = PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: gwen, recap: "The ferry burned.")
    scene = Scene.start!(second, title: "The ferryman's price", by: gwen, opening: { question: "Is he honest?", odds: 2 })
    scene.end!(by: gwen)
    Scene.start!(second, title: "Road to the mill", by: gwen).end!(by: gwen)
    second.end!(by: gwen)
    PlaySession.start!(@campaign, characters: [ characters(:tibbs) ], by: gwen)
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select ".previously__title a[href=?]", campaign_play_session_path(@campaign, second), "Session 2"
    assert_select ".previously__meta", /2 scenes · 1 roll/
    assert_select ".previously__recap", "The ferry burned."
    assert_select ".previously__scenes li", 2
    assert_select ".previously__scenes li:first-child .previously__outcome", /\Astory roll · (perfect|messy|grim|disaster)\z/
    assert_select ".previously__quote", 0, "no best moments"
    assert_select ".older-sessions__number", "S1"
    assert_select ".older-sessions__all[href=?]", campaign_play_sessions_path(@campaign), "All 3 sessions"
  end

  test "the GM sees pools at a glance and how many are hidden; players roll the visible ones here" do
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)
    assert_select "#pools .pool-glance", 2, "the hidden ambush isn't listed"
    assert_select "#pools .pool-glance__hidden", /1 hidden pool, only you see it/
    assert_select "#rolls", 0, "the GM rolls story at the table"
    assert_select ".table-rail", 0

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    brawl = "##{dom_id(pools(:brawl))}"
    assert_select "#pools .pool-row", 2
    assert_select "#pools .pool-glance__hidden", 0
    assert_select "#{brawl} .badge--push", "Nothing dropped: push?"
    assert_select "#{brawl} details.pool-row__more form[action=?]", campaign_pool_push_path(@campaign, pools(:brawl))
    assert_select "#{brawl} details.pool-row__more form[action=?] input[name=drop_first][value='1']", campaign_pool_roll_path(@campaign, pools(:brawl))
    assert_select "#rolls form[action=?]", campaign_story_rolls_path(@campaign)
    assert_select ".table-rail #table_feed"
    assert_select ".table-rail form[action=?]", campaign_notes_path(@campaign)
  end

  test "at the table: members with their character or role, and kept crucibles hidden until there are some" do
    @campaign.memberships.create!(identity: identities(:stranger), role: :player)
    sign_in_as identities(:pip)

    get campaign_path(@campaign)
    assert_select ".members__item", 3
    assert_select ".members__item:has(.members__name:contains('Gwen')) .members__role--gm", "GM"
    assert_select ".members__item:has(.members__name:contains('Pip')) .members__role", "Tibbs"
    assert_select ".members__item:has(.members__name:contains('Stranger')) .members__role", "making one"
    assert_select ".campaign-actions__row a.button:not(.button--ghost)[href=?]", edit_campaign_path(@campaign), "Campaign settings"
    assert_select "[data-controller=kept-crucibles][hidden] button[data-action=?]", "kept-crucibles#clear", "Clear"
  end

  test "the GM sets the pitch in settings; players can only leave" do
    sign_in_as identities(:gwen)
    get edit_campaign_path(@campaign)
    assert_select "form[action=?] input[name='campaign[party_is][]']", campaign_path(@campaign), 2
    assert_select "#settings form[action=?]", campaign_join_code_path(@campaign)
    assert_select "#settings form[action=?] button", campaign_path(@campaign), "Delete campaign"

    patch campaign_path(@campaign), params: { campaign: { name: "Bramblewood", pitch: " Drowned villages. ", party_is: [ "Wardens", "", "Outsiders", "Extra" ], group_arc: "uncover the truth" } }
    assert_redirected_to campaign_path(@campaign)
    @campaign.reload
    assert_equal [ "Drowned villages.", %w[ Wardens Outsiders ], "uncover the truth" ], [ @campaign.pitch, @campaign.party_is, @campaign.group_arc ]

    patch campaign_path(@campaign), params: { campaign: { name: "", pitch: "x" * 201 } }
    assert_response :unprocessable_entity
    assert_select ".form-error", /Name can't be blank.*Pitch is too long/
    assert_select ".toasts .toast .toast__message", "That didn't save. Check the form for what to fix."

    sign_out
    sign_in_as identities(:pip)
    get edit_campaign_path(@campaign)
    assert_select "#settings form[action=?]", campaign_membership_path(@campaign, memberships(:pip_player))
    assert_select "input[name='campaign[pitch]']", 0
    assert_select "form[action=?] button", campaign_path(@campaign), count: 0

    patch campaign_path(@campaign), params: { campaign: { pitch: "Mine now" } }
    assert_response :forbidden
  end

  test "a character's owner marks them fallen or retired" do
    sign_in_as identities(:pip)
    patch character_path(characters(:tibbs)), params: { character: { status: "retired" } }
    assert characters(:tibbs).reload.retired?
    assert_nil memberships(:pip_player).seated_character, "a retired character isn't who you play"

    patch character_path(characters(:tibbs)), params: { character: { status: "vanished" } }
    assert_response :unprocessable_entity
  end

  test "a new pool that doesn't save shows the GM table again, form open" do
    sign_in_as identities(:gwen)

    post campaign_pools_path(@campaign), params: { pool: { name: "", starting_size: 4 } }
    assert_response :unprocessable_entity
    assert_select "details#pool-new[open] .form-error", /Name can't be blank/
    assert_select "details#pool-new[data-controller=menu][data-action~='turbo:submit-end->menu#closeOnSuccess'] [data-menu-target=panel]"
    assert_select "details.pool-card__more[data-controller=menu] .pool-card__menu[data-menu-target=panel]", minimum: 1
    assert_select "#pools .pool-card", 3
  end

  test "a crucible embeds in the table's frame" do
    get crucible_path("gm", embed: 1)
    assert_response :success
    assert_select "turbo-frame#crucible [data-controller=crucible][data-crucible-key-value=gm]"
    assert_select "turbo-frame#crucible [data-crucible-target=table]", 2

    get crucible_path("gm")
    assert_select "turbo-frame#crucible", count: 0
    assert_select "h1", "GM crucible"
  end
end
