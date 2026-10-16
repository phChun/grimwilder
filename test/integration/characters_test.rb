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

  test "roll a stat from the sheet, spending spark" do
    @tibbs.update!(marked_agility: true)
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "a[href=?]", new_character_roll_path(@tibbs, stat: "agility"), text: "Roll 3d +1t"

    get new_character_roll_path(@tibbs, stat: "agility")
    assert_response :success
    assert_select "input[name=spark]", 2, "0 or the 1 spark Tibbs holds"
    assert_select ".page-header__lede", /\+1t from damage \(marked\)/
    assert_select "input[name='assists[]'][value=?]", characters(:bram).id.to_s

    assert_difference -> { @tibbs.rolls.count }, 1 do
      post character_rolls_path(@tibbs), params: { stat: "agility", mode: "defense", spark: 1, help: 1, thorns: 2, assists: [ characters(:bram).id ] }
    end
    roll = @tibbs.rolls.last
    assert_redirected_to character_roll_path(@tibbs, roll)
    assert_equal [ "defense", 5, 3 ], [ roll.kind, roll.dice.size, roll.thorns.size ]
    assert_equal [ "Bram" ], roll.assists.pluck("name")
    assert_not @tibbs.reload.marked_agility?

    follow_redirect!
    assert_select ".result__name", roll.outcome.capitalize
    assert_select ".page-header__lede", "3d Agility + 1 spark + 1d extra + Bram assisting, vs 3t (marked, 2 situational)"
    assert_select ".tray .die--assist[title=Bram]", 1
  end

  test "only characters seated alongside can assist" do
    sign_in_as identities(:pip)

    assert_no_difference -> { Roll.count } do
      post character_rolls_path(@tibbs), params: { stat: "agility", assists: [ characters(:loner).id ] }
    end
    assert_redirected_to character_path(@tibbs)
    assert_match(/can assist/, flash[:alert])
  end

  test "a roll outside the rules goes back to the sheet" do
    sign_in_as identities(:pip)

    assert_no_difference -> { Roll.count } do
      post character_rolls_path(@tibbs), params: { stat: "agility", spark: 2 }
    end
    assert_redirected_to character_path(@tibbs)
    assert_equal "Gibbletibble \"Tibbs\" can spend 0–1 spark.", flash[:alert]
  end

  test "XP and conditions" do
    sign_in_as identities(:pip)

    post character_experience_path(@tibbs)
    post character_experience_path(@tibbs)
    assert_equal 2, @tibbs.reload.level

    post character_conditions_path(@tibbs), params: { condition: "4d poisoned" }
    post character_conditions_path(@tibbs), params: { condition: "twisted ankle", lasts: "scene" }
    assert_equal [ { "name" => "4d poisoned", "lasts" => nil }, { "name" => "twisted ankle", "lasts" => "scene" } ], @tibbs.reload.conditions
    delete character_condition_path(@tibbs, 1)
    delete character_condition_path(@tibbs, 0)
    assert_empty @tibbs.reload.conditions
  end

  test "the GM can read a seated character but not change it" do
    sign_in_as identities(:gwen)

    get character_path(@tibbs)
    assert_response :success
    assert_select ".stat-card__roll", count: 0

    patch character_path(@tibbs), params: { character: { spark: 0 } }
    assert_response :forbidden

    post character_rolls_path(@tibbs), params: { stat: "agility" }
    assert_response :not_found
    get new_character_roll_path(@tibbs, stat: "agility")
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
