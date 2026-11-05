require "test_helper"

class IdentityRemovalTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @gwen, @pip, @stranger = identities(:gwen), identities(:pip), identities(:stranger)
  end

  test "a player's account goes, with their characters; their rolls and lines stay, as a removed account's" do
    roll = Roll.note!(campaign: @campaign, by: @pip, text: "Tibbs hums")
    line = @campaign.messages.create!(identity: @pip, kind: "table_talk", body: "Hi")
    tibbs = characters(:tibbs).id

    @pip.remove!

    assert_not Identity.exists?(@pip.id)
    assert_not Character.exists?(tibbs)
    assert_equal [ memberships(:gwen_gm) ], @campaign.memberships.to_a
    assert_nil roll.reload.identity_id
    assert_equal "Removed account", roll.identity.display_name
    assert_equal "Pip", line.reload.name, "the name copied in stays"
    assert_equal "Removed account", line.identity.display_name
    assert_includes Roll.table_log(memberships(:gwen_gm)), roll
  end

  test "whispers to them go, so a player's never reads as one to the GM" do
    @campaign.memberships.create!(identity: @stranger, role: :player)
    to_pip = @campaign.messages.create!(identity: @stranger, kind: "whisper", body: "Psst", to_character: characters(:tibbs))
    from_pip = @campaign.messages.create!(identity: @pip, kind: "whisper", body: "Psst")

    @pip.remove!

    assert_not Message.exists?(to_pip.id)
    assert Message.exists?(from_pip.id)
  end

  test "not while they're the only GM of a campaign others are in" do
    assert_match "only GM of The Bramblewood Accord", @gwen.removal_blocked_by
    assert_raises(ArgumentError) { @gwen.remove! }
    assert Identity.exists?(@gwen.id)
    assert_equal 2, @campaign.memberships.count

    @campaign.memberships.create!(identity: @stranger, role: :gm)
    assert_nil @gwen.removal_blocked_by
    @gwen.remove!
    assert_equal [ @pip, @stranger ].sort_by(&:id), @campaign.reload.identities.sort_by(&:id)
  end

  test "a campaign they're alone in goes with them" do
    solo = Campaign.create_with_gm!(name: "Alone", gm: @stranger)
    wren = characters(:loner).id

    @stranger.remove!

    assert_not Campaign.exists?(solo.id)
    assert_not Character.exists?(wren)
  end

  test "a removed account's leftovers still need an account to be made" do
    assert_not @campaign.messages.new(kind: "table_talk", body: "Hi").valid?
    assert_raises(ActiveRecord::RecordInvalid) { Roll.create!(campaign: @campaign, kind: "note", name: "X", question: "Y") }
  end
end
