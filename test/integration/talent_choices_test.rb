require "test_helper"

class TalentChoicesTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs) # pip's Rogue, at gwen's table: Expertise is the core
  end

  test "the form lists a closed list as checkboxes, in the book's groups" do
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ stealth ])
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(@tibbs, "expertise")

    assert_response :success
    assert_select "turbo-frame#modal h1", "Expertise"
    assert_equal [ "Above board", "Below table" ], css_select(".talent-choice__group-name").map(&:text)
    assert_select "input[type=checkbox][name='picks[skills][]']", 12
    assert_select "input[type=checkbox][value=stealth][checked]"
    assert_select ".talent-choice__count", "1 of 3"
  end

  test "an open list is a type-or-pick box per slot" do
    @tibbs.update!(level: 2, talent_keys: %w[ lucky wisps ])
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(@tibbs, "wisps")

    assert_select "input[type=text][name='picks[traits][]'][list=choice-traits-list]", 2
    assert_select "datalist#choice-traits-list option[value=Petty]"
  end

  test "the owner saves picks and goes back to the talent" do
    sign_in_as identities(:pip)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: [ "", "Duel", "stealth" ] } }

    assert_redirected_to character_path(@tibbs, anchor: "talent-expertise")
    assert_equal %w[ duel stealth ], @tibbs.reload.talent_choices.dig("expertise", "skills")

    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: [ "" ] } }
    assert_empty @tibbs.reload.talent_choices, "unticking every box clears them"
  end

  test "a bad pick shows the form again with what went wrong" do
    sign_in_as identities(:pip)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: %w[ duel evade lying stealth ] } }

    assert_response :unprocessable_entity
    assert_select ".form-error", /room for 3 skills/
    assert_empty @tibbs.reload.talent_choices
  end

  test "the GM can pick for a player's character; other players can't; strangers get a 404" do
    sign_in_as identities(:gwen)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: %w[ track ] } }
    assert_equal %w[ track ], @tibbs.reload.talent_choices.dig("expertise", "skills")

    sign_out
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(characters(:bram), "weapon-mastery")
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: %w[ duel ] } }
    assert_response :not_found
  end

  test "a talent with nothing to pick, or one the character lacks, is a 404" do
    sign_in_as identities(:pip)
    @tibbs.update!(talent_keys: [ "lucky" ])
    get edit_character_talent_choices_path(@tibbs, "lucky")
    assert_response :not_found

    get edit_character_talent_choices_path(@tibbs, "flight")
    assert_response :not_found
  end
end
