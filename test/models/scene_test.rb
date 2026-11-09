require "test_helper"

class SceneTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @session = PlaySession.start!(@campaign, characters: [ @tibbs, @bram ], by: identities(:gwen))
  end

  test "scenes are numbered per session, one at a time, and need a title" do
    scene = Scene.start!(@session, title: "  The bridge  at Mirefall ", by: identities(:gwen))
    assert_equal [ 1, "The bridge at Mirefall" ], [ scene.number, scene.title ]
    assert_equal scene, @campaign.current_scene
    assert_equal "Session 1 · Scene 1: The bridge at Mirefall", @campaign.rolls.marker.last.name

    assert_raises(ArgumentError) { Scene.start!(@session, title: "Another", by: identities(:gwen)) }
    scene.end!(by: identities(:gwen))
    second = Scene.start!(@session, title: "The ford", by: identities(:gwen))
    assert_equal 2, second.number

    second.end!(by: identities(:gwen))
    assert_raises(ActiveRecord::RecordInvalid) { Scene.start!(@session, title: " ", by: identities(:gwen)) }
  end

  test "a scene with a story question opens with the first story roll asking it" do
    scene = Scene.start!(@session, title: "The bridge", by: identities(:gwen), story_question: "  Is it  guarded? ")
    assert_equal "Is it guarded?", scene.story_question

    Roll.story!(campaign: @campaign, by: identities(:gwen), question: "Who's there?")
    assert_nil scene.reload.opening_roll, "another question isn't the opening"
    opening = Roll.story!(campaign: @campaign, by: identities(:gwen), question: "is it guarded?")
    Roll.story!(campaign: @campaign, by: identities(:gwen), question: "Is it guarded?")
    assert_equal opening, scene.reload.opening_roll
    assert_equal [ scene, @session ], [ opening.scene, opening.play_session ]
  end

  test "a scene with no story question opens with no roll" do
    scene = Scene.start!(@session, title: "The bridge", by: identities(:gwen))
    Roll.story!(campaign: @campaign, by: identities(:gwen), question: "Is it guarded?")
    assert_nil scene.reload.opening_roll
  end

  test "rolls during a scene are stamped with it; between scenes they aren't" do
    scene = Scene.start!(@session, title: "The bridge", by: identities(:gwen))
    during = @tibbs.roll!("wits", by: identities(:pip))
    scene.end!(by: identities(:gwen))
    after = @tibbs.roll!("wits", by: identities(:pip))

    assert_equal scene, during.scene
    assert_nil after.scene
    assert_equal @session, after.play_session
  end

  test "ending a scene clears the scene conditions picked, and leaves the rest" do
    @tibbs.update!(conditions: [ { name: "twisted ankle", lasts: "scene" }, { name: "broken arm" }, { name: "drunk", lasts: "scene" } ])
    @bram.update!(conditions: [ { name: "winded", lasts: "scene" } ])
    scene = Scene.start!(@session, title: "The bridge", by: identities(:gwen))

    assert_equal [ [ @tibbs, 0, "twisted ankle" ], [ @tibbs, 2, "drunk" ], [ @bram, 0, "winded" ] ].map { |c, i, n| [ c.id, i, n ] },
      scene.lingering_conditions.map { |c, i, condition| [ c.id, i, condition["name"] ] }.sort_by { |id, i, _| [ id == @tibbs.id ? 0 : 1, i ] }

    scene.end!(by: identities(:gwen), clear: [ "#{@tibbs.id}:0", "#{@bram.id}:0", "#{@tibbs.id}:1" ], notes: "They crossed.")
    assert_equal [ "broken arm", "drunk" ], @tibbs.reload.conditions.pluck("name"), "broken arm isn't a scene condition, and drunk was left"
    assert_empty @bram.reload.conditions
    assert_match "twisted ankle cleared", @campaign.rolls.marker.last.question
    assert_equal "They crossed.", scene.reload.notes
  end

  test "a closing roll must be a montage from this scene" do
    scene = Scene.start!(@session, title: "The climb", by: identities(:gwen))
    montage = Roll.montage!(campaign: @campaign, by: identities(:gwen), participants: [ { character: @tibbs } ])
    story = Roll.story!(campaign: @campaign, by: identities(:gwen))

    assert_raises(ArgumentError) { scene.end!(by: identities(:gwen), closing_roll: story) }
    scene.end!(by: identities(:gwen), closing_roll: montage)
    assert_equal montage, scene.reload.closing_roll
  end

  test "ending the session ends its open scene first, clearing conditions too" do
    @tibbs.update!(conditions: [ { name: "twisted ankle", lasts: "scene" } ])
    scene = Scene.start!(@session, title: "The bridge", by: identities(:gwen))

    @session.end!(by: identities(:gwen), clear: [ "#{@tibbs.id}:0" ])
    assert_not scene.reload.open?
    assert_empty @tibbs.reload.conditions
    assert_equal [ "Scene 1 ends", "Session 1 ends" ], @campaign.rolls.marker.order(:id).last(2).map(&:name)
  end

  test "notes go in the log with no dice" do
    Scene.start!(@session, title: "The bridge", by: identities(:gwen))
    note = Roll.note!(campaign: @campaign, by: identities(:pip), text: "  Tibbs enters a frenzy  ")

    assert note.note?
    assert_equal [ "Pip", "Tibbs enters a frenzy", [] ], [ note.name, note.question, note.dice ]
    assert note.scene
    assert_raises(ActiveRecord::RecordInvalid) { Roll.note!(campaign: @campaign, by: identities(:pip), text: " ") }
  end
end
