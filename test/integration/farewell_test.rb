require "test_helper"

# A character's story ending (Character::Farewell): the player marks them
# fallen or retired from the sheet, and can bring them back.
class FarewellTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs = characters(:tibbs)
  end

  test "the player marks their character fallen, with a farewell, and brings them back" do
    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select ".adjust__farewell form[action=?]", character_story_end_path(@tibbs) do
      assert_select "button[name=status][value=fallen]", "Mark fallen"
      assert_select "button[name=status][value=retired]", "Retire Tibbs"
    end

    assert_difference -> { @campaign.rolls.where(kind: "note").count }, 1 do
      post character_story_end_path(@tibbs), params: { status: "fallen", farewell: "  Held the bridge so the others could run. " }
    end
    assert_redirected_to character_path(@tibbs)
    assert @tibbs.reload.fallen?
    assert_equal "Held the bridge so the others could run.", @tibbs.farewell
    assert @tibbs.status_changed_at
    assert_equal "Gibbletibble \"Tibbs\" has fallen. “Held the bridge so the others could run.”", @campaign.rolls.last.question

    follow_redirect!
    assert_select ".farewell-banner--fallen .farewell-banner__words", "“Held the bridge so the others could run.”"
    assert_select ".stat-roll", 0, "no rolling once they've fallen"
    assert_select ".adjust__farewell", 0
    assert_raises(ArgumentError) { @tibbs.roll!("wits", by: identities(:pip)) }

    get characters_path
    assert_select ".farewells .farewell-card--fallen a[href=?]", character_path(@tibbs)
    assert_select ".character-list a[href=?]", character_path(@tibbs), 0

    delete character_story_end_path(@tibbs)
    assert @tibbs.reload.active?
    assert_nil @tibbs.farewell
    assert_equal "Gibbletibble \"Tibbs\" returns to play.", @campaign.rolls.last.question
  end

  test "only the owner ends their story, and not while up for grabs" do
    sign_in_as identities(:gwen)
    post character_story_end_path(@tibbs), params: { status: "retired" }
    assert_response :not_found
    assert @tibbs.reload.active?

    bram = characters(:bram)
    bram.update!(up_for_grabs: true)
    post character_story_end_path(bram), params: { status: "retired" }
    assert bram.reload.active?
    assert_raises(ArgumentError) { bram.end_story!("lost", by: identities(:gwen)) }
  end
end
