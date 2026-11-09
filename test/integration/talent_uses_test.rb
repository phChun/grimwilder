require "test_helper"

class TalentUsesTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @fen = identities(:pip).characters.create!(name: "Fen", path: "Bard", brawn: 1, agility: 2, wits: 2, presence: 3,
      campaign: @campaign, talent_keys: [ "bardic-lore" ])
  end

  test "the owner ticks uses on the sheet; they go in the log when the GM says so" do
    sign_in_as identities(:pip)

    get character_path(@fen)
    assert_select "#talent-inspiration .use-tracker", /Inspiration/
    assert_select "#talent-inspiration button.use-box", 3
    assert_select "#talent-inspiration .use-tracker__resets", "3 left · resets each session"
    assert_select "#talent-bardic-lore .talent-card__chip", "+1 thread each session"
    assert_select "#talents input[type=checkbox]", 0, "no checkbox of the player's own"

    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 1 }
    assert_redirected_to character_path(@fen, anchor: "talent-inspiration")
    assert_equal 1, @fen.reload.talent_uses["inspiration/inspiration"]
    assert_equal 0, @campaign.rolls.note.count, "off by default"

    @campaign.update!(log_talent_uses: true)
    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 2 }
    assert_equal "Fen spends inspiration", @campaign.rolls.note.last.question

    patch character_talent_uses_path(@fen), params: { use: "inspiration/inspiration", spent: 0 }
    assert_equal 0, @fen.reload.talent_uses["inspiration/inspiration"]
    assert_equal 1, @campaign.rolls.note.count, "unspending doesn't post"

    # Bardic Lore: thread resets to 3, not 2
    get character_path(@fen)
    assert_select ".identity .tally--thread .tally__count", "2 of 3 thread"
    assert_select ".identity .tally--spark form[action=?] button[aria-label=?]", character_path(@fen), "Take spark"
    assert_select ".identity .tally--xp form[action=?] button", character_experience_path(@fen)
    assert_select ".identity a[href=?]", edit_character_path(@fen), "Edit sheet"
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
    @fen.update!(level: 2, talent_keys: [ "bardic-lore", "lucky" ])
    PlaySession.start!(@campaign, characters: [ @fen ], by: identities(:gwen))
    luck = @fen.talent_pools.sole
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select "#table .party-card__uses", "Inspiration 4/4"
    assert_select "#table .seat-pool__name", "Luck"
    assert_select "#pools ##{dom_id(luck)}", 0

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#pools ##{dom_id(luck)}", 0, "talent pools stay on the sheet"

    get character_path(@fen)
    assert_select "#talent-lucky ##{dom_id(luck)}", 1, "a talent pool sits under its talent"
    assert_select "#talent-lucky ##{dom_id(luck)} .pool-row__more", 0, "Luck only rolls: no ⋯"

    post campaign_pool_roll_path(@campaign, luck), params: { return_to: "character" }
    assert_redirected_to character_path(@fen, anchor: "talent-lucky")
    assert luck.reload.last_rolled_at
  end

  test "at 0d the GM can reset a talent pool from the table" do
    @fen.update!(level: 2, talent_keys: [ "bardic-lore", "lucky" ])
    PlaySession.start!(@campaign, characters: [ @fen ], by: identities(:gwen))
    luck = @fen.talent_pools.sole
    reset = campaign_pool_reset_path(@campaign, luck)
    sign_in_as identities(:gwen)

    get campaign_table_path(@campaign)
    assert_select ".seat-pool form[action=?]", reset, 0, "only once it's spent"

    luck.roll!(by: identities(:pip), random: FixedDice.new([ 1 ] * Pool::MAX_SIZE))
    get campaign_table_path(@campaign)
    assert_select ".seat-pool form[action=?]", reset

    get character_path(@fen)
    assert_select "#talent-lucky form[action=?]", reset, 0, "not on the sheet"

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts @fen do
        post reset
      end
    end
    assert_redirected_to campaign_table_path(@campaign, anchor: dom_id(luck))
    assert_equal luck.starting_size, luck.reload.size
    assert_equal "Gwen resets Fen: Luck to 1d", @campaign.rolls.note.last.question
  end

  test "on the sheet, a talent pool gets ⋯ only when there's more than Roll" do
    ash = identities(:pip).characters.create!(name: "Ash", path: "Cleric", brawn: 2, agility: 1, wits: 2, presence: 3,
      campaign: @campaign, level: 2, talent_keys: [ "bulwark" ])
    PlaySession.start!(@campaign, characters: [ ash ], by: identities(:gwen))
    rite = ash.talent_pools.find_by!(use_key: "channel-divinity/major-rite")
    bulwark = ash.talent_pools.find_by!(use_key: "bulwark/bulwark")
    sign_in_as identities(:pip)

    get character_path(ash)
    assert_select "##{dom_id(bulwark)} form[action=?]", campaign_pool_roll_path(@campaign, bulwark), 1
    assert_select "##{dom_id(bulwark)} .pool-row__more", 0
    assert_select "##{dom_id(rite)} .pool-row__more input[name=drop_first]", 2, "drop 1d, and potent on the action roll"
    assert_select "##{dom_id(rite)} .pool-row__more input[name=as_action]"
  end
end
