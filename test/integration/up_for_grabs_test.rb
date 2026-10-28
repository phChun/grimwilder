require "test_helper"

# The GM makes characters for the table, or takes any back, and players pick
# them (Character::Claiming).
class UpForGrabsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "the GM makes one for the table; a player picks it and it's theirs" do
    sign_in_as identities(:gwen)
    get campaign_path(@campaign)
    assert_select "#party .party-grid a.add-card--link:last-child[href=?]", new_character_path(campaign_id: @campaign.id, up_for_grabs: 1), /Create new character/

    post characters_path, params: { character: { name: "Marlo", path: "Ranger", brawn: 2, agility: 3, wits: 2, presence: 1, campaign_id: @campaign.id, up_for_grabs: "1" } }
    marlo = Character.find_by!(name: "Marlo")
    assert marlo.up_for_grabs?
    assert marlo.owned_by?(identities(:gwen)), "the GM holds it until it's picked"

    get campaign_path(@campaign)
    assert_select "#up-for-grabs .grabs__name", "Marlo"
    assert_select "#up-for-grabs form[action=?]", character_claim_path(marlo), 0, "the GM waits for a player"
    assert_select "#party .hero-card__name", { text: "Marlo", count: 0 }, "not in the party yet"

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#up-for-grabs form[action=?] button", character_claim_path(marlo), "Play Marlo"

    get character_path(marlo)
    assert_select ".identity__line", { text: /played by/, count: 0 }, "the GM only holds it"

    assert_difference -> { @campaign.rolls.where(kind: "note").count }, 1 do
      post character_claim_path(marlo)
    end
    assert_redirected_to character_path(marlo)
    marlo.reload
    assert marlo.owned_by?(identities(:pip))
    assert_not marlo.up_for_grabs?
    assert_equal "Pip picks Marlo.", @campaign.rolls.where(kind: "note").last.question

    post character_claim_path(marlo)
    assert_equal "Someone else picked Marlo first.", flash[:alert]
  end

  test "the GM puts a player's character up for grabs, and someone else can pick it" do
    sign_in_as identities(:gwen)
    get character_path(characters(:bram))
    assert_select ".claim-bar", 0, "the GM's own character: from the edit page"
    get edit_character_path(characters(:bram))
    assert_select "form[action=?] button", character_claim_path(characters(:bram)), "Put Bram up for grabs"

    get character_path(@tibbs)
    assert_select ".claim-bar form[action=?] button", character_claim_path(@tibbs), "Put up for grabs"

    delete character_claim_path(@tibbs)
    assert_redirected_to campaign_path(@campaign, anchor: "up-for-grabs")
    @tibbs.reload
    assert @tibbs.up_for_grabs?
    assert @tibbs.owned_by?(identities(:gwen))
    assert_nil memberships(:pip_player).seated_character
    assert_not_includes @campaign.resting_characters, @tibbs, "no rests or attendance while nobody plays it"

    get character_path(@tibbs)
    assert_select ".claim-bar--open", /Waiting for a player/
  end

  test "a player gives theirs back, but can't give away anyone else's" do
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select ".claim-bar", 0, "the owner gives it back from the edit page"
    get edit_character_path(@tibbs)
    assert_select "form[action=?] button", character_claim_path(@tibbs), "Give Tibbs back"

    delete character_claim_path(characters(:bram))
    assert_redirected_to character_path(characters(:bram))
    assert_match(/isn't yours to give up/, flash[:alert])
    assert_not characters(:bram).reload.up_for_grabs?

    delete character_claim_path(@tibbs)
    assert @tibbs.reload.up_for_grabs?
    assert @tibbs.owned_by?(identities(:gwen)), "back to the GM"
  end

  test "only a GM can offer a character up for grabs, and outsiders can't pick" do
    sign_in_as identities(:pip)
    post characters_path, params: { character: { name: "Sly", path: "Rogue", brawn: 1, agility: 3, wits: 3, presence: 1, campaign_id: @campaign.id, up_for_grabs: "1" } }
    assert_response :unprocessable_entity
    sign_out

    @tibbs.update!(identity: identities(:gwen), up_for_grabs: true)
    sign_in_as identities(:stranger)
    post character_claim_path(@tibbs)
    assert_response :not_found
  end
end
