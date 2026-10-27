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
    assert_redirected_to new_character_talent_path(ash), "next: a first talent"
    assert_equal campaigns(:bramblewood), ash.campaign
    assert_equal [ "scarred knuckles" ], ash.features

    follow_redirect!
    assert_select "a[href=?]", character_path(ash), "Skip for now"

    get edit_character_path(ash)
    assert_select ".talent-names li", 1
    assert_select ".talent-names li .tag", "core"
    assert_select "a[href=?]", new_character_talent_path(ash), "Choose 1 more talent"
  end

  test "the features crucible rolls inside the form and fills the feature boxes" do
    sign_in_as identities(:gwen)
    get new_character_path

    assert_select "fieldset[data-controller=feature-fill][data-action=?]", "crucible:pick->feature-fill#fill" do
      assert_select "input[data-feature-fill-target=input]", 3
      assert_select "details.feature-crucible turbo-frame#crucible[loading=lazy][src=?]", crucible_path("features", embed: 1)
    end
    assert_select "a[href=?]", crucible_path("features"), 0, "no trip to another page"
  end

  test "a new character can start at a higher level, with a talent for each" do
    sign_in_as identities(:pip)
    get new_character_path
    assert_select "select[name='character[level]'] option", 7

    post characters_path, params: { character: { name: "Ash", path: "Fighter", level: 3, brawn: 3, agility: 2, wits: 2, presence: 1 } }
    ash = Character.find_by!(name: "Ash")
    assert_equal [ 3, 3 ], [ ash.level, ash.talents_to_choose ]
    assert_redirected_to new_character_talent_path(ash)
    assert_equal "Ash is ready. Now choose 3 talents.", flash[:notice]
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

  test "the form has a bond for each other character at the table, and nobody else" do
    bram = characters(:bram)
    @tibbs.update!(bonds: [ { "to" => "Bram", "bond" => "tense rivalry" }, { "to" => "Lillylux", "bond" => "lowkey affection" } ])
    sign_in_as identities(:pip)

    get edit_character_path(@tibbs)
    assert_select ".bond-row", 1
    assert_select ".bond-row label", /Bram\s+played by Gwen/
    assert_select ".bond-row input[type=hidden][name='character[bonds][0][character_id]'][value=?]", bram.id.to_s
    assert_select ".bond-row input[name='character[bonds][0][bond]'][value=?]", "tense rivalry"
    assert_select ".bond-row", text: /Tibbs/, count: 0
    assert_select ".bonds-npcs[data-controller=bonds][data-bonds-next-value=3]" do
      assert_select "input[name='character[bonds][1][to]'][value=?]", "Lillylux"
      assert_select "input[name='character[bonds][2][to]'][value='']", 1, "a blank row for a new NPC"
      assert_select "button[data-action='bonds#add']", "Add an NPC"
    end
    assert_match %r{<template data-bonds-target="template"[^>]*>.*name="character\[bonds\]\[__INDEX__\]\[to\]"}m, response.body

    patch character_path(@tibbs), params: { character: { bonds: {
      "0" => { "character_id" => bram.id, "to" => "Bram", "bond" => "deep respect" },
      "1" => { "to" => "", "bond" => "" },
      "2" => { "to" => "Miller Hode", "bond" => "growing doubts" },
      "7" => { "to" => "Sister Ivy", "bond" => "deep devotion" }
    } } }
    assert_equal [ { "to" => "Bram", "bond" => "deep respect", "character_id" => bram.id },
      { "to" => "Miller Hode", "bond" => "growing doubts" }, { "to" => "Sister Ivy", "bond" => "deep devotion" } ], @tibbs.reload.bonds

    get character_path(@tibbs)
    assert_select ".facts__list li", "Bram · Deep Respect"
    assert_select ".facts__list li", "Miller Hode · Growing Doubts"
  end

  test "who they are: lists, title-cased, with what they're not" do
    @tibbs.update!(traits: [ "brave", "quick-witted" ], not_trait: "rash", desires: [ "glory" ], arcs: [ "uncover the truth" ],
      bonds: [ { "to" => "Lillylux", "bond" => "lowkey affection" } ])
    sign_in_as identities(:pip)
    get character_path(@tibbs)

    assert_select ".facts div", text: /Traits/ do
      assert_select ".facts__list li", 3
      assert_select ".facts__list li", "Brave"
      assert_select ".facts__list li", "Quick-Witted"
      assert_select ".facts__list li.facts__not", "But not Rash"
    end
    assert_select ".facts__list li.facts__arc", "Uncover the Truth"
    assert_select ".facts__list li", "Lillylux · Lowkey Affection"
    assert_equal [ "brave", "quick-witted" ], @tibbs.reload.traits, "stored as typed"
  end

  test "roll a stat from the sheet, spending spark" do
    @tibbs.update!(marked_agility: true)
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select ".stat-card details.stat-roll", 4
    assert_select ".stat-card--marked button.mark-toggle[aria-pressed=true]", "Marked"
    assert_select ".stat-card button.mark-toggle[aria-pressed=false]", { count: 3, text: "Mark" }
    assert_select "#damage .mark-toggle", 0, "marks are on the stat cards now"
    assert_select "details.stat-roll summary", text: "Roll Agility"
    assert_select "details.stat-roll .popover__head button.close-button[aria-label=Close]", 4
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
    assert_select "#roll-toast", 0, "no roll yet"

    assert_difference -> { @tibbs.rolls.count }, 1 do
      post character_rolls_path(@tibbs), params: { stat: "agility", mode: "defense", spark: 1, help: 1, thorns: 2, assists: [ characters(:bram).id ] }
    end
    roll = @tibbs.rolls.last
    assert_redirected_to character_path(@tibbs)
    assert_equal [ "defense", 5, 3 ], [ roll.kind, roll.dice.size, roll.thorns.size ]
    assert_equal [ "Bram" ], roll.assists.pluck("name")
    assert_not @tibbs.reload.marked_agility?

    follow_redirect!
    assert_select "#roll-toast .roll-toast__title", /Agility defense · just now$/
    assert_select "#roll-toast .roll-result__word", roll.critical? ? "Critical" : roll.outcome.capitalize
    assert_select "#roll-toast .roll-result__reason", /#{Regexp.escape(RollsHelper::RESULT_TEXT["defense"][roll.outcome])}/
    assert_select "#roll-toast .roll-toast__setup", "3d Agility + 1 spark + 1d extra + Bram assisting, vs 3t (marked, 2 situational)"
    assert_select "#roll-toast .roll-result__dice .die--assist[title=Bram]", 1
    assert_select "#table_feed ##{ActionView::RecordIdentifier.dom_id(roll)}", 1, "the table's log sits beside the sheet"
  end

  test "the roll's toast is gone 10 seconds on, unless a critical is still waiting on its choice" do
    sign_in_as identities(:pip)
    roll = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 4, 2, 1 ]))

    get character_path(@tibbs)
    assert_select "#roll-toast[data-toast-sticky-value=false][data-toast-seconds-value]", 1

    travel 11.seconds do
      get character_path(@tibbs)
      assert_select "#roll-toast", 0
    end

    roll.update!(dice: [ 6, 6, 2 ], outcome: "perfect", critical: true)
    travel 5.minutes do
      get character_path(@tibbs)
      assert_select "#roll-toast[data-toast-sticky-value=true] .critical__spark", 1
    end
  end

  test "the steppers send totals: the roll takes what's on top of the stat and the damage" do
    @tibbs.update!(marked_agility: true, bloodied: true)
    sign_in_as identities(:pip)

    post character_rolls_path(@tibbs), params: { stat: "agility", mode: "action", dice: 4, total_thorns: 3 }
    roll = @tibbs.rolls.last
    assert_equal [ 1, 4, 3, [ "marked", "bloodied" ] ], [ roll.help_dice, roll.dice.size, roll.thorns.size, roll.damage_reasons ]

    post character_rolls_path(@tibbs), params: { stat: "wits", mode: "action", dice: 3, total_thorns: 0, help_from: "the innkeeper" }
    assert_match "1d from the innkeeper", ApplicationController.helpers.roll_setup(@tibbs.rolls.last)
  end

  test "talents that fit a stat are ticks in its setup, and the log names them" do
    @tibbs.update!(talent_keys: [ "lightning-reflexes" ])
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm stealth ])
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#roll_agility_bonus_expertise-skill[value='expertise/skill'][data-dice='1']", 1
    assert_select ".stat-roll__talent", text: /Using a chosen skill \(Charm, Stealth\)/
    assert_select ".stat-roll__talent--auto[data-defense-only=true]", text: /Lightning Reflexes/, count: 1

    post character_rolls_path(@tibbs), params: { stat: "agility", mode: "action", dice: 3, total_thorns: 0, bonuses: [ "expertise/skill" ] }
    roll = @tibbs.rolls.last
    assert_equal [ 4, "Expertise" ], [ roll.dice.size, roll.talent_bonuses.sole["name"] ]

    get character_path(@tibbs)
    assert_select ".roll-toast__setup", text: /3d Agility \+ 1d Expertise/
  end

  test "Cast opens the casting stat's setup with the spell ticked" do
    @tibbs.update!(path: "Wizard", talent_keys: [])
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#talent-spellcraft a[href='#{character_path(@tibbs, cast: "spellcraft", anchor: "stats")}']", text: /Cast/
    assert_select "details.stat-roll[open]", 0

    get character_path(@tibbs, cast: "spellcraft")
    assert_select "details.stat-roll[open]", 1
    assert_select "details.stat-roll[open] #roll_wits_bonus_spellcraft-cast[checked]", 1
    assert_select "#roll_wits_bonus_spellcraft-potent[checked]", 0

    post character_rolls_path(@tibbs), params: { stat: "wits", mode: "action", dice: 2, total_thorns: 0, bonuses: [ "spellcraft/cast" ] }
    assert_equal 1, @tibbs.reload.uses_spent(@tibbs.use_counters.find { _1.id == "spellcraft/spells" })
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

    get character_path(@tibbs)
    assert_select "form.condition-form input[type=number][name=dice][aria-label=?]", "Dice (optional)"
    assert_select "form.condition-form input[type=text][name=condition]"

    post character_conditions_path(@tibbs), params: { condition: "4d poisoned" }
    post character_conditions_path(@tibbs), params: { condition: "twisted ankle", lasts: "scene", dice: "" }
    post character_conditions_path(@tibbs), params: { condition: "burning", dice: "3" }
    post character_conditions_path(@tibbs), params: { condition: "2d cursed", dice: "5" }
    assert_equal [ { "name" => "4d poisoned", "lasts" => nil }, { "name" => "twisted ankle", "lasts" => "scene" },
      { "name" => "3d burning", "lasts" => nil }, { "name" => "2d cursed", "lasts" => nil } ], @tibbs.reload.conditions
    delete character_condition_path(@tibbs, 3)
    delete character_condition_path(@tibbs, 2)
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
