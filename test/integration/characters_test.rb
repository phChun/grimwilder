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
    assert_select ".stat-card details.stat-roll", 4
    assert_select ".stat-card--marked .tag--marked", "Marked"
    assert_select "details.stat-roll summary .stat-roll__open", text: "Roll Agility"
    assert_select "details.stat-roll form[action=?]", character_rolls_path(@tibbs) do |forms|
      agility = forms.find { _1.at_css("input[name=stat][value=agility]") }
      assert_equal 2, agility.css("input[name=spark]").size, "0 or the 1 spark Tibbs holds"
      assert agility.at_css("input[name=dice][value='3'][min='3']"), "dice start at the stat"
      assert agility.at_css("input[name=total_thorns][value='1'][min='1']"), "thorns start with the mark's"
      assert_match "1 thorn from the mark, already added", agility.text
      assert_equal "Roll 3d + 1t", agility.at_css("button[name=mode][value=action]").text
      assert agility.at_css("button[name=mode][value=defense]")
      assert agility.at_css("input[name='assists[]'][value='#{characters(:bram).id}']")
    end
    assert_select "#last-roll", 0, "no roll yet"

    assert_difference -> { @tibbs.rolls.count }, 1 do
      post character_rolls_path(@tibbs), params: { stat: "agility", mode: "defense", spark: 1, help: 1, thorns: 2, assists: [ characters(:bram).id ] }
    end
    roll = @tibbs.rolls.last
    assert_redirected_to character_path(@tibbs)
    assert_equal [ "defense", 5, 3 ], [ roll.kind, roll.dice.size, roll.thorns.size ]
    assert_equal [ "Bram" ], roll.assists.pluck("name")
    assert_not @tibbs.reload.marked_agility?

    follow_redirect!
    assert_select "#last-roll .last-roll__title", "Last roll · Agility defense · just now"
    assert_select "#last-roll .roll-result__word", roll.critical? ? "Critical" : roll.outcome.capitalize
    assert_select "#last-roll .roll-result__reason", /#{Regexp.escape(RollsHelper::RESULT_TEXT["defense"][roll.outcome])}/
    assert_select "#last-roll .last-roll__setup", "3d Agility + 1 spark + 1d extra + Bram assisting, vs 3t (marked, 2 situational)"
    assert_select "#last-roll .roll-result__dice .die--assist[title=Bram]", 1
    assert_select "#table_feed ##{ActionView::RecordIdentifier.dom_id(roll)}", 1, "the table's log sits beside the sheet"
  end

  test "the steppers send totals: the roll takes what's on top of the stat and the damage" do
    @tibbs.update!(marked_agility: true, bloodied: true)
    sign_in_as identities(:pip)

    post character_rolls_path(@tibbs), params: { stat: "agility", mode: "action", dice: 4, total_thorns: 3 }
    roll = @tibbs.rolls.last
    assert_equal [ 1, 4, 3, [ "marked", "bloodied" ] ], [ roll.help_dice, roll.dice.size, roll.thorns.size, roll.damage_reasons ]
  end

  test "a stat that isn't one never reaches the character" do
    sign_in_as identities(:pip)

    assert_no_difference -> { Roll.count } do
      post character_rolls_path(@tibbs), params: { stat: "destroy", dice: 3, total_thorns: 0 }
    end
    assert_redirected_to character_path(@tibbs)
    assert Character.exists?(@tibbs.id)
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

  test "a condition that's a pool rolls from the Harm card and goes in the log" do
    @tibbs.update!(conditions: [ "4d poisoned", "broken arm" ])
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#damage .condition", 2
    assert_select "#damage .condition__size", "4d"
    assert_select "#damage button[aria-label=?]", "Roll 4d poisoned", 1
    assert_select "#damage button[aria-label=?]", "Roll broken arm", 0, "not a pool"

    post character_condition_roll_path(@tibbs, 0)
    assert_redirected_to character_path(@tibbs, anchor: "damage")
    roll = @tibbs.rolls.last
    assert_equal [ "pool", "Gibbletibble \"Tibbs\": poisoned", 4 ], [ roll.kind, roll.name, roll.dice.size ]
    assert_equal "#{roll.remaining}d poisoned", @tibbs.reload.conditions.first["name"]
    assert_equal campaigns(:bramblewood), roll.campaign

    post character_condition_roll_path(@tibbs, 1)
    assert_equal "broken arm isn't a pool to roll.", flash[:alert]
  end

  test "the sheet says when someone else changed harm" do
    @tibbs.update!(bloodied: true, marked_agility: true)
    campaigns(:bramblewood).rest!(by: identities(:gwen))
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#damage .harm__changed", /\AGM cleared Bloodied and the Agility mark · less than a minute ago\z/

    patch character_path(@tibbs), params: { quick: 1, character: { rattled: true } }
    follow_redirect!
    assert_select "#damage .harm__changed", 0, "the owner's own change replaces it"
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
