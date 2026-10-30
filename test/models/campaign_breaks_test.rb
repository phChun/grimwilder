require "test_helper"

class CampaignBreaksTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @tibbs.update!(marked_agility: true, bloodied: true, desperate: true, conditions: [ "4d poisoned", "lost an eye" ])
    @bram.update!(rattled: true)
  end

  test "a rest clears marks and harm, but not conditions" do
    @campaign.rest!(by: identities(:gwen))

    assert_not @tibbs.reload.marked_agility?
    assert_not @tibbs.bloodied?
    assert_not @tibbs.desperate?
    assert_not @bram.reload.rattled?
    assert_equal 2, @tibbs.conditions.size
    assert_equal "Rest", @campaign.rolls.marker.last.name
  end

  test "during a session, only the characters there rest" do
    PlaySession.start!(@campaign, characters: [ @bram ], by: identities(:gwen))
    @campaign.rest!(by: identities(:gwen))

    assert @tibbs.reload.bloodied?
    assert_not @bram.reload.rattled?
  end

  test "downtime heals the conditions picked, resets talents, and rolls campaign pools" do
    faction = @campaign.pools.create!(name: "The Guild's reach", kind: "campaign", starting_size: 4)
    @bram.update!(talent_keys: [ "control" ], talent_uses: { "control/control" => 1, "weapon-mastery/mastery" => 2 })

    @campaign.downtime!(by: identities(:gwen), clear: [ "#{@tibbs.id}:0" ], random: FixedDice.new([ 1, 2, 5, 6 ]))

    assert_equal [ "lost an eye" ], @tibbs.reload.conditions.pluck("name"), "left unticked as permanent"
    assert_not @tibbs.bloodied?
    assert_empty @bram.reload.talent_uses
    assert_equal 2, faction.reload.size
    assert_equal [ "Downtime", "The Guild's reach" ], @campaign.rolls.order(:id).last(2).map { _1.marker? ? _1.name : _1.pool.name }
  end

  test "downtime depletes the campaign pool the GM picks, after the rolls" do
    guild = @campaign.pools.create!(name: "The Guild's reach", kind: "campaign", starting_size: 4)
    winter = @campaign.pools.create!(name: "Winter comes", kind: "campaign", starting_size: 4)

    @campaign.downtime!(by: identities(:gwen), deplete: winter.id, random: FixedDice.new([ 6, 6, 6, 6, 6, 6, 6, 6 ]))

    assert_equal 4, guild.reload.size
    assert winter.reload.depleted?
    assert_equal "depleted", winter.last_action
    assert_equal [ "rolled", "depleted" ], winter.rolls.order(:id).pluck(:pool_action)
  end

  test "depleting a linked pool ends its last phase" do
    pool = @campaign.pools.create!(name: "The war", kind: "campaign", phases_text: "4d Border raids + 4d Siege")
    pool.deplete!(by: identities(:gwen))

    assert pool.reload.depleted?
    assert_equal "Siege", pool.phase_name
  end

  test "downtime refills talent pools" do
    @bram.update!(talent_keys: [ "bulwark" ])
    PlaySession.start!(@campaign, characters: [ @bram ], by: identities(:gwen)).end!(by: identities(:gwen))
    bulwark = @bram.talent_pools.sole
    bulwark.roll!(by: identities(:gwen), random: FixedDice.new([ 1, 1 ]))

    @campaign.downtime!(by: identities(:gwen))
    assert_equal 2, bulwark.reload.size
  end

  test "only campaign pools roll in downtime" do
    @campaign.downtime!(by: identities(:gwen))
    assert_equal 6, pools(:lookouts).reload.size
  end
end
