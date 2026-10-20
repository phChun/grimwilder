require "test_helper"

# Who last changed marks, harm or conditions, and what changed, so the sheet
# can say so when it wasn't the owner.
class CharacterHarmChangeTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs)
    @gwen = identities(:gwen)
  end

  test "a change with no one named isn't recorded" do
    @tibbs.update!(bloodied: true)
    assert_nil @tibbs.harm_change
  end

  test "marking and clearing harm and marks" do
    @tibbs.changed_by = @gwen
    @tibbs.update!(bloodied: true, marked_wits: true)
    assert_equal "marked Bloodied and Wits", @tibbs.harm_change
    assert_equal @gwen, @tibbs.harm_changed_by
    assert @tibbs.harm_changed_by_someone_else?

    @tibbs.rest!(by: @gwen)
    assert_equal "cleared Bloodied and the Wits mark", @tibbs.harm_change
  end

  test "conditions added, cleared and rolled" do
    @tibbs.changed_by = @gwen
    @tibbs.add_condition!("4d poisoned")
    assert_equal "added 4d poisoned", @tibbs.harm_change

    @tibbs.roll_condition!(0, by: @gwen, random: FixedDice.new([ 1, 5, 2, 6 ]))
    assert_equal "rolled 4d poisoned: 2d left", @tibbs.harm_change
    assert_equal "2d poisoned", @tibbs.conditions.first["name"]

    @tibbs.remove_condition!(0)
    assert_equal "cleared 2d poisoned", @tibbs.harm_change
  end

  test "a condition pool rolled down to 0d stays until it's cleared" do
    @tibbs.update!(conditions: [ "2d poisoned" ])
    roll = @tibbs.roll_condition!(0, by: identities(:pip), random: FixedDice.new([ 1, 3 ]))

    assert_equal [ 2, 0 ], [ roll.dropped, roll.remaining ]
    assert_equal "0d poisoned", @tibbs.reload.conditions.first["name"]
    assert_raises(ArgumentError) { @tibbs.roll_condition!(0, by: identities(:pip)) }
    assert_not @tibbs.harm_changed_by_someone_else?, "the owner rolled it"
  end

  test "ending a scene records the GM clearing scene conditions" do
    session = PlaySession.start!(campaigns(:bramblewood), characters: [ @tibbs ], by: @gwen)
    scene = Scene.start!(session, title: "The mill fire", by: @gwen)
    @tibbs.update!(conditions: [ { "name" => "smoke in the eyes", "lasts" => "scene" } ])

    scene.end!(by: @gwen, clear: [ "#{@tibbs.id}:0" ])
    assert_equal [ "cleared smoke in the eyes", @gwen ], [ @tibbs.reload.harm_change, @tibbs.harm_changed_by ]
  end
end
