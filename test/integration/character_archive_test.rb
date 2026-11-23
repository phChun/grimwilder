require "test_helper"

# Archiving a character (Character::Archive): put away at the foot of the
# Characters page, out of any table they're playing at, and back again.
class CharacterArchiveTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs, @campaign = characters(:tibbs), campaigns(:bramblewood)
    sign_in_as identities(:pip)
  end

  test "archiving takes a playing character out of their table and to the foot of the list; unarchiving brings them back unseated" do
    get characters_path
    assert_select ".character-list form[action=?]", character_archive_path(@tibbs)

    post character_archive_path(@tibbs)
    assert_redirected_to characters_path
    @tibbs.reload
    assert @tibbs.archived?
    assert_nil @tibbs.campaign, "out of the party"
    assert_equal "#{@tibbs.name} leaves the table.", @campaign.rolls.note.last.question

    follow_redirect!
    assert_select ".character-list .tool-card__name", { text: @tibbs.name, count: 0 }
    assert_select ".archive-list .archive-list__name", @tibbs.name
    assert_select ".archive-list form[action=?] input[name=_method][value=delete]", character_archive_path(@tibbs)

    get character_path(@tibbs)
    assert_select ".archived-banner", /Archived/
    assert_not @tibbs.in_play?

    assert_raises(ArgumentError) { @tibbs.seat!(@campaign, by: identities(:pip)) }

    delete character_archive_path(@tibbs), params: { return_to: "character" }
    assert_redirected_to character_path(@tibbs)
    assert_not @tibbs.reload.archived?
    assert_nil @tibbs.campaign
  end

  test "a fallen character stays remembered at their table when archived; up for grabs can't be; strangers can't" do
    @tibbs.end_story!("fallen", by: identities(:pip))
    post character_archive_path(@tibbs)
    assert @tibbs.reload.archived?
    assert_equal @campaign, @tibbs.campaign

    post character_archive_path(characters(:bram))
    assert_response :not_found
  end

  test "the seat dropdown lists campaigns still playing before archived ones" do
    Campaign.create_with_gm!(name: "Zephyr Keep", gm: identities(:pip))
    @campaign.update_columns(archived_at: Time.current)

    get characters_path
    options = css_select("#seat_#{@tibbs.id} option").map(&:text)
    assert_equal [ "Not in a campaign", "Zephyr Keep", "#{@campaign.name} (archived)" ], options, "by name, The Bramblewood Accord would come first"
  end

  test "the sheet's options menu archives, moves and deletes, for the owner only" do
    get character_path(@tibbs)
    assert_select "#character-options" do
      assert_select "a[href=?]", edit_character_path(@tibbs, anchor: "at-the-table"), "Move to another table"
      assert_select "form[action=?] button", character_seat_path(@tibbs), "Take Tibbs out of #{@campaign.name}"
      assert_select "a[href=?]", edit_character_path(@tibbs, anchor: "story-ends")
      assert_select "form[action=?] button", character_archive_path(@tibbs), "Archive Tibbs"
      assert_select "form[action=?] button", character_path(@tibbs), "Delete Tibbs"
    end

    sign_out
    sign_in_as identities(:gwen)
    get character_path(@tibbs)
    assert_select "#character-options", 0, "the GM reads the sheet, without the owner's options"
  end

  test "the Characters page's ⋯ deletes, and an archived character's ⋯ unarchives or deletes" do
    get characters_path
    assert_select "##{dom_id(@tibbs, :more)} form[action=?] button.button--delete", character_path(@tibbs), "Delete"

    post character_archive_path(@tibbs)
    get characters_path
    assert_select "##{dom_id(@tibbs, :archived_more)}" do
      assert_select "form[action=?] button", character_archive_path(@tibbs), "Unarchive"
      assert_select "form[action=?] button.button--delete", character_path(@tibbs), "Delete"
    end

    assert_difference -> { Character.count }, -1 do
      delete character_path(@tibbs)
    end
    assert_redirected_to characters_path
  end
end
