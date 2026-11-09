require "test_helper"

# On hold (Campaign::Hold): a GM over their plan's limit (Identity::Plans#apply_plan!)
# keeps the most recently played campaign going and the rest wait. Chat and
# sheets go on; play doesn't. The GM chooses which to play from the list.
class CampaignHoldTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
    @gwen = identities(:gwen)
    @gwen.update!(plan: "tester")
    @campaign.update_columns(created_at: 1.month.ago)
    @other = Campaign.create_with_gm!(name: "Saltmarsh", gm: @gwen)
    @gwen.apply_plan!("free")
  end

  test "the list says what's on hold, and the GM plays it instead of the other" do
    assert @campaign.reload.on_hold?

    sign_in_as @gwen
    get campaigns_path
    assert_select ".hold-banner", "You're on Free, which runs 1 campaign at a time. The Bramblewood Accord is on hold. Choose which to play, archive one, or upgrade."
    assert_select ".campaign-card--on-hold .tool-card__desc", /On hold/
    assert_select ".campaign-card--on-hold form[action=?][data-turbo-confirm=?] button", campaign_hold_path(@campaign),
      "Play The Bramblewood Accord? Saltmarsh goes on hold in its place.", "Play this one"

    delete campaign_hold_path(@campaign)
    assert_redirected_to campaigns_path
    assert_not @campaign.reload.on_hold?
    assert @other.reload.on_hold?
  end

  test "play waits on hold: sessions, scenes, rolls, roll calls, pools, the GM table" do
    sign_in_as @gwen
    get campaign_table_path(@campaign)
    assert_redirected_to campaign_path(@campaign)

    assert_no_difference -> { PlaySession.count } do
      post campaign_play_sessions_path(@campaign), params: { character_ids: [ @tibbs.id ] }
    end
    assert_equal "The Bramblewood Accord is on hold. Its GM can choose to play it from the campaigns list.", flash[:alert]

    assert_no_difference -> { @campaign.rolls.count } do
      post campaign_pool_roll_path(@campaign, pools(:lookouts))
      post campaign_story_rolls_path(@campaign), params: { question: "Is the bridge out?", odds: 2 }
    end
    assert_no_difference -> { RollCall.count } do
      post campaign_story_rolls_path(@campaign), params: { question: "Is the bridge out?", odds: 1, character_id: @tibbs.id }
    end
    assert_no_difference -> { Pool.count } do
      post campaign_pools_path(@campaign), params: { pool: { name: "Fire", kind: "task", starting_size: 4 } }
    end

    assert_raises(ArgumentError) { PlaySession.start!(@campaign.reload, characters: [ @tibbs ], by: @gwen) }
    assert_raises(ArgumentError) { @tibbs.reload.roll!("wits", by: identities(:pip)) }
    assert_not pools(:lookouts).reload.rollable?
    assert_not @tibbs.in_play?
    assert_not RollCall.new(campaign: @campaign).tap(&:validate).errors[:base].empty?
  end

  test "chat, sheet edits and joining go on, and players are told why" do
    sign_in_as identities(:pip)
    assert_difference -> { Message.count } do
      post campaign_messages_path(@campaign), params: { context: "talk", body: "Still on for Friday?" }
    end
    patch character_story_path(@tibbs), params: { character: { notes: "Owes the miller." } }
    assert_equal "Owes the miller.", @tibbs.reload.notes

    get campaign_path(@campaign)
    assert_select ".campaign-hero__hold", /On hold\s+Your GM's plan has this campaign on hold\. Chat and sheets still work\./
    assert_select ".table-rail .composer"
    get character_path(@tibbs)
    assert_select ".claim-bar", /The Bramblewood Accord is on hold/
    assert_select ".stat-roll", 0

    newcomer = Identity.create!(email_address: "new@example.com", name: "Nell")
    assert @campaign.memberships.create(identity: newcomer).persisted?
  end

  test "archiving a held campaign drops its hold, and it can't come back without room" do
    @campaign.reload.archive!(by: @gwen)
    assert_not @gwen.membership_in(@campaign).held?
    assert_not @other.reload.on_hold?

    error = assert_raises(ArgumentError) { @campaign.reload.unarchive!(by: @gwen) }
    assert_match(/can't come back from the archive/, error.message)
    assert @campaign.reload.archived?
  end
end
