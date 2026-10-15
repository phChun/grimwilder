require "test_helper"

class CharactersTest < ActionDispatch::IntegrationTest
  setup { @tibbs = characters(:tibbs) }

  test "make a character from the form" do
    sign_in_as identities(:gwen)

    assert_difference -> { identities(:gwen).characters.count }, 1 do
      post characters_path, params: { character: {
        name: "Ash", path: "Fighter", brawn: 3, agility: 2, wits: 2, presence: 1, campaign_id: campaigns(:bramblewood).id,
        backgrounds: { "0" => { name: "Warrior", wises: [ "battle plans", "improvised weapons", "war stories" ] } },
        traits: %w[brave stubborn], not_trait: "gentle", features: [ "scarred knuckles", "", "" ]
      } }
    end

    ash = Character.find_by!(name: "Ash")
    assert_redirected_to character_path(ash)
    assert_equal campaigns(:bramblewood), ash.campaign
    assert_equal [ "scarred knuckles" ], ash.features
  end

  test "a bad stat spread shows the form again" do
    sign_in_as identities(:gwen)

    post characters_path, params: { character: { name: "Ash", path: "Fighter", brawn: 3, agility: 3, wits: 3, presence: 3 } }
    assert_response :unprocessable_entity
  end

  test "quick updates from the sheet" do
    sign_in_as identities(:pip)

    patch character_path(@tibbs), params: { quick: 1, character: { spark: 2, bloodied: true } }
    assert_redirected_to character_path(@tibbs)
    assert_equal 2, @tibbs.reload.spark
    assert @tibbs.bloodied?
  end

  test "rolling a stat sends its dice and damage thorns to the roller" do
    @tibbs.update!(marked_agility: true)
    sign_in_as identities(:pip)

    post character_rolls_path(@tibbs), params: { stat: "agility" }
    assert_redirected_to roll_path(dice: 3, thorns: 1, for: "Gibbletibble \"Tibbs\": Agility", reasons: "marked", character_id: @tibbs.id)
    assert_not @tibbs.reload.marked_agility?

    follow_redirect!
    assert_select "[data-roller-dice-value='3'][data-roller-thorns-value='1']"
    assert_select "a[href=?]", character_path(@tibbs)
  end

  test "XP and conditions" do
    sign_in_as identities(:pip)

    post character_experience_path(@tibbs)
    post character_experience_path(@tibbs)
    assert_equal 2, @tibbs.reload.level

    post character_conditions_path(@tibbs), params: { condition: "4d poisoned" }
    assert_equal [ "4d poisoned" ], @tibbs.reload.conditions
    delete character_condition_path(@tibbs, 0)
    assert_empty @tibbs.reload.conditions
  end

  test "the GM can read a seated character but not change it" do
    sign_in_as identities(:gwen)

    get character_path(@tibbs)
    assert_response :success
    assert_select "button", text: /Roll/, count: 0

    patch character_path(@tibbs), params: { character: { spark: 0 } }
    assert_response :forbidden

    post character_rolls_path(@tibbs), params: { stat: "agility" }
    assert_response :not_found
  end

  test "outsiders can't see a character" do
    sign_in_as identities(:stranger)

    get character_path(@tibbs)
    assert_response :not_found
  end

  test "campaign page lists seated characters" do
    sign_in_as identities(:gwen)

    get campaign_path(campaigns(:bramblewood))
    assert_select "a[href=?]", character_path(@tibbs)
  end
end
