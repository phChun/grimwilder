require "test_helper"

class TalentUsesTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @fen = identities(:pip).characters.create!(name: "Fen", path: "Bard", brawn: 1, agility: 2, wits: 2, presence: 3,
      campaign: @campaign, talent_keys: [ "bardic-lore" ])
  end

  test "the owner ticks uses on the sheet, and can post them to the log" do
    sign_in_as identities(:pip)

    get character_path(@fen)
    assert_select "#talent-inspiration .use-tracker", /Inspiration/
    assert_select "#talent-inspiration button.use-box", 3
    assert_select "#talent-inspiration", /Resets each session/
    assert_select "#talent-bardic-lore .talent-card__chip", "+1 thread each session"
    assert_select "#talents input[data-talent-uses-target=note]"

    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 1, note: "1" }
    assert_redirected_to character_path(@fen, anchor: "talent-inspiration")
    assert_equal 1, @fen.reload.talent_uses["inspiration/inspiration"]
    assert_equal "Fen spends inspiration", @campaign.rolls.note.last.question

    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 0, note: "1" }
    assert_equal 0, @fen.reload.talent_uses["inspiration/inspiration"]
    assert_equal 1, @campaign.rolls.note.count, "unspending doesn't post"

    # Bardic Lore: thread resets to 3, not 2
    get character_path(@fen)
    assert_select ".identity .pips--thread[aria-label=?]", "2 of 3 thread"
  end

  test "the GM can tick a player's uses; other players can't" do
    sign_in_as identities(:gwen)
    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 2 }
    assert_equal 2, @fen.reload.talent_uses["inspiration/inspiration"]

    sign_out
    bram_owner = identities(:pip)
    other = characters(:bram)
    sign_in_as bram_owner
    patch character_talent_uses_path(other), params: { use: "weapon-mastery/mastery", spent: 1 }
    assert_response :forbidden
    assert_empty other.reload.talent_uses

    sign_out
    sign_in_as identities(:stranger)
    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 0 }
    assert_response :not_found
  end

  test "the table shows uses left and talent pools under the character, not with the shared pools" do
    @fen.update!(talent_keys: [ "bardic-lore", "lucky" ])
    PlaySession.start!(@campaign, characters: [ @fen ], by: identities(:gwen))
    luck = @fen.talent_pools.sole
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select "#table .party-card__uses", "Inspiration 3/3"
    assert_select "#table .seat-pool__name", "Luck"
    assert_select "#pools ##{dom_id(luck)}", 0

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#pools ##{dom_id(luck)}", 0, "talent pools stay on the sheet"

    get character_path(@fen)
    assert_select "#talent-lucky ##{dom_id(luck)}", 1, "a talent pool sits under its talent"

    post campaign_pool_roll_path(@campaign, luck), params: { return_to: "character" }
    assert_redirected_to character_path(@fen, anchor: "talent-lucky")
    assert luck.reload.last_rolled_at
  end
end
