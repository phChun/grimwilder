require "test_helper"

class TalentSkinsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @fen = identities(:pip).characters.create!(name: "Fen", path: "Bard", brawn: 1, agility: 2, wits: 2, presence: 3,
      campaign: @campaign, talent_keys: [ "bardic-lore" ])
  end

  test "the sheet lists each talent with its summary, uses and full text in a fold-out" do
    sign_in_as identities(:pip)
    get character_path(@fen)

    assert_select "#talent-inspiration .talent-card__name", "Inspiration"
    assert_select "#talent-inspiration .talent-card__summary", Talent.find("inspiration").summary
    assert_select "#talent-inspiration details.talent-card__more .talent-card__text", /Each session, you have 3 inspiration/
    assert_select "#talent-bardic-lore details form[action=?]", character_talent_skin_path(@fen, "bardic-lore")
    assert_select "#talent-uses", 0, "no separate uses panel any more"
  end

  test "the owner re-skins a talent and can put it back" do
    sign_in_as identities(:pip)

    patch character_talent_skin_path(@fen, "bardic-lore"), params: { skin: { name: "  Songs of  Old ", summary: "", text: "I know the old songs.\n\nAll of them." } }
    assert_redirected_to character_path(@fen, anchor: "talent-bardic-lore")
    assert_equal({ "name" => "Songs of Old", "text" => "I know the old songs.\n\nAll of them." }, @fen.reload.talent_skins["bardic-lore"])

    get character_path(@fen)
    assert_select "#talent-bardic-lore .talent-card__name", "Songs of Old"
    assert_select "#talent-bardic-lore .talent-card__aka", "Re-skinned Bardic Lore"
    assert_select "#talent-bardic-lore .talent-card__summary", Talent.find("bardic-lore").summary
    assert_select "#talent-bardic-lore .talent-card__text--own", 2
    assert_select "#talent-bardic-lore .talent-card__text", /You gain any 3 wises/, "the book's text stays"

    delete character_talent_skin_path(@fen, "bardic-lore")
    assert_not @fen.reload.talent_skins.key?("bardic-lore")
  end

  test "the core talent can be re-skinned, and blank fields clear the skin" do
    @fen.reskin_talent!("inspiration", "summary" => "Hype the party.")
    assert_equal "Hype the party.", @fen.talent_entry("inspiration").summary

    @fen.reskin_talent!("inspiration", "name" => "", "summary" => " ")
    assert_empty @fen.reload.talent_skins
  end

  test "removing a talent drops its skin; talents the character lacks can't be re-skinned" do
    @fen.reskin_talent!("bardic-lore", "name" => "Songs of Old")
    @fen.remove_talent!("bardic-lore")
    assert_empty @fen.reload.talent_skins

    assert_raises(ActiveRecord::RecordNotFound) { @fen.reskin_talent!("lucky", "name" => "Charmed") }
  end

  test "the GM can re-skin a player's talent; other players can't" do
    sign_in_as identities(:gwen)
    patch character_talent_skin_path(@fen, "inspiration"), params: { skin: { name: "Battle Hymn" } }
    assert_equal "Battle Hymn", @fen.reload.talent_skins.dig("inspiration", "name")

    sign_out
    sign_in_as identities(:pip)
    patch character_talent_skin_path(characters(:bram), "weapon-mastery"), params: { skin: { name: "Mine" } }
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    patch character_talent_skin_path(@fen, "inspiration"), params: { skin: { name: "Nope" } }
    assert_response :not_found
  end
end
