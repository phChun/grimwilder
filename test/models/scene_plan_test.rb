require "test_helper"

class ScenePlanTest < ActiveSupport::TestCase
  setup { @campaign = campaigns(:bramblewood) }

  test "plans line up in the order made, with an optional story question" do
    first = @campaign.scene_plans.create!(title: " The  bridge ", story_question: " ")
    second = @campaign.scene_plans.create!(title: "The mill", story_question: " Is the  miller home? ")
    assert_equal [ "The bridge", first, second ], [ first.title, *@campaign.scene_plans.ordered ]
    assert_equal [ nil, "Is the miller home?" ], [ first.story_question, second.story_question ]
    assert_not @campaign.scene_plans.new(title: "Long", story_question: "?" * 201).valid?
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

  test "a scene's collection must be this campaign's" do
    other = campaigns(:bramblewood).scene_collections.create!(title: "The castle")
    assert @campaign.scene_plans.new(title: "Gate", scene_collection: other).valid?
    elsewhere = Campaign.create_with_gm!(name: "Elsewhere", gm: identities(:tess)).scene_collections.create!(title: "Docks")
    assert_not @campaign.scene_plans.new(title: "Gate", scene_collection: elsewhere).valid?
  end
end
