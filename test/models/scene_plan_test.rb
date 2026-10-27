require "test_helper"

class ScenePlanTest < ActiveSupport::TestCase
  setup { @campaign = campaigns(:bramblewood) }

  test "plans line up in the order made, and an opening needs real odds" do
    first = @campaign.scene_plans.create!(title: " The  bridge ")
    second = @campaign.scene_plans.create!(title: "The mill", opening_odds: 3)
    assert_equal [ "The bridge", first, second ], [ first.title, *@campaign.scene_plans.ordered ]
    assert_not first.opening?
    assert second.opening?
    assert_not @campaign.scene_plans.new(title: "Odd", opening_odds: 4).valid?
  end

  test "starting a scene from a plan makes it that scene's, and a reset frees it" do
    plan = @campaign.scene_plans.create!(title: "The bridge")
    session = PlaySession.start!(@campaign, characters: [], by: identities(:gwen))
    scene = Scene.start!(session, title: plan.title, notes: "Toll-keepers.", plan: plan, by: identities(:gwen))
    assert_equal [ scene, "Toll-keepers." ], [ plan.reload.scene, scene.notes ]
    assert_empty @campaign.scene_plans.unplayed

    @campaign.reset!(by: identities(:gwen))
    assert_equal [ plan ], @campaign.scene_plans.unplayed.to_a, "its scene is gone, so it's back to play"
  end
end
