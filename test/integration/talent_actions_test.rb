require "test_helper"

# A talent's card on the sheet: its badges, its rolls and Push yourself.
class TalentActionsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @tibbs.update!(level: 2, talent_keys: %w[ mastermind lurker ])
  end

  test "the core talent leads, every card says what it is, and the owner gets its actions" do
    sign_in_as identities(:pip)
    get character_path(@tibbs)

    assert_select ".talent-list .talent-card--core", 0, "the core talent sits above the grid"
    assert_select "#talents > .talent-card--core#talent-expertise + .talent-list > .talent-card", 2
    assert_select "#talents > .talent-card--core#talent-expertise" do
      assert_select ".talent-card__source", /Core talent · Rogue/
      assert_select ".talent-card__growth", /At levels 3 and 6/
      assert_select ".talent-kind--uses", "Uses" # Competence: 2 points a session
    end
    assert_select "#talent-mastermind" do
      assert_select ".talent-kind--roll", "Roll"
      assert_select "form[action=?] button.talent-card__roll", character_talent_roll_path(@tibbs, "mastermind"), /Flashback: the preparation\s+3d montage · spends 1 thread/
      assert_select ".talent-card__menu button", text: "Remove talent"
    end
    assert_select "#talent-lurker .talent-card__push" do
      assert_select "summary", /Push yourself\s+mark a stat/
      assert_select "button.talent-card__push-stat", 4
    end
    assert_select "#talent-expertise .talent-card__menu button", text: "Remove talent", count: 0

    post character_talent_roll_path(@tibbs, "mastermind"), params: { index: 0 }
    assert_redirected_to character_path(@tibbs, anchor: "talent-mastermind")
    assert @campaign.roll_calls.open.sole.montage?

    post character_talent_push_path(@tibbs, "lurker"), params: { stat: "wits" }
    assert @tibbs.reload.marked_wits?
    follow_redirect!
    assert_select ".toast", /Tibbs marks Wits\./
  end

  test "others at the table see the cards without the actions" do
    sign_in_as identities(:gwen)
    get character_path(@tibbs)

    assert_select "#talent-mastermind .talent-kind--roll"
    assert_select ".talent-card__roll", 0
    assert_select ".talent-card__push", 0
    post character_talent_roll_path(@tibbs, "mastermind"), params: { index: 0 }
    assert_response :not_found
  end

  test "Magus: enchant the weapon from its card, then end it for a potent effect" do
    @tibbs.update!(path: "Warlock", talent_keys: %w[ magus lurker ])
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "#talent-magus datalist#enchant-traits option[value=Pulverizing]"

    patch character_talent_state_path(@tibbs, "magus"), params: { change: "enchant", trait: "Seeking" }
    assert_redirected_to character_path(@tibbs, anchor: "talent-magus")
    follow_redirect!
    assert_select "#talent-magus .talent-state__on", "Seeking"

    patch character_talent_state_path(@tibbs, "magus"), params: { change: "disenchant" }
    follow_redirect!
    assert_select "#talent-magus .use-tracker__resets", "not enchanted"
  end

  test "Oathsworn's card: violate and atone each tenet, and give Affirmation's spark" do
    @tibbs.update!(path: "Paladin", talent_keys: %w[ aegis lurker ])
    @tibbs.choose_for_talent!("oathsworn", "tenets" => [ "never flee" ])
    sign_in_as identities(:pip)

    patch character_talent_state_path(@tibbs, "oathsworn"), params: { change: "violate", tenet: "never flee" }
    follow_redirect!
    assert_select "#talent-oathsworn .oath-tenets__tenet--violated", "Never Flee"
    assert_select "#talent-oathsworn .oath-tenets", /1 less smite/
    assert_select "#talent-oathsworn select[name=ally_id] option", text: "Bram"

    patch character_talent_state_path(@tibbs, "oathsworn"), params: { change: "affirm", ally_id: characters(:bram).id }
    follow_redirect!
    assert_select "#talent-oathsworn select[name=ally_id]", 0, "once a session"
  end

  test "Monster Menagerie's card picks the creature that answers" do
    @tibbs.update!(path: "Summoner", talent_keys: %w[ monster-menagerie lurker ])
    @tibbs.choose_for_talent!("monster-menagerie", "creatures" => [ "Grimfang", "Mote" ])
    sign_in_as identities(:pip)

    patch character_talent_state_path(@tibbs, "monster-menagerie"), params: { change: "answer", creature: "Grimfang" }
    follow_redirect!
    assert_select "#talent-monster-menagerie .talent-state__on", "Grimfang"
    assert_select "#talent-monster-menagerie button", text: "Mote"
  end

  test "a talent the book gave to another path says so quietly, and stays" do
    @tibbs.update_columns(talent_keys: %w[ folk-hero ])
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "#talent-folk-hero .talent-card__only", "Now Bard only; kept on this sheet."

    @tibbs.update!(path: "Bard")
    get character_path(@tibbs)
    assert_select "#talent-folk-hero .talent-card__only", 0
  end

  test "outside a session, a talent you roll says it's for a session, and still rolls" do
    @tibbs.update!(level: 2, talent_keys: %w[ mastermind lurker ])
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "#talent-mastermind .talent-card__session", /Roll it in a session/
    assert_select "#talent-mastermind .talent-card__between"
    assert_select "#talent-lurker .talent-card__session", 0, "nothing to roll"

    PlaySession.start!(campaigns(:bramblewood), characters: [ @tibbs ], by: identities(:gwen))
    get character_path(@tibbs)
    assert_select ".talent-card__session", 0
  end
end
