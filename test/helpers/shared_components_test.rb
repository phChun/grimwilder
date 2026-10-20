require "test_helper"

# The night-table shell's shared partials, rendered on their own.
class SharedComponentsTest < ActionView::TestCase
  include RollsHelper, IconsHelper

  test "a die shows its state, tier and size" do
    render "shared/die", value: 5, state: :highest, size: 32
    assert_select "span.die.die--d6.die--messy.die--top.die--32[aria-label=?]", "d6 showing 5", "5"

    render "shared/die", value: 2, state: :dropped
    assert_select "span.die--dropped.die--44", "2"

    render "shared/die", value: 7, kind: "d8"
    assert_select "span.die--d8.die--cut[aria-label=?]", "thorn showing 7"
  end

  test "a roll result has dice, a word and a reason" do
    roll = Roll.new(kind: "action", stat: "agility", outcome: "grim", dice: [ 2, 5, 4 ], thorns: [ 7 ])
    render "shared/roll_result", roll: roll

    assert_select ".roll-result.roll-result--grim .roll-result__word", "Grim"
    assert_select ".roll-result__dice .die--top", "5"
    assert_select ".roll-result__dice .die--cut", "7"
    assert_select ".roll-result__reason", "Messy, cut to grim by a thorn"
  end

  test "reasons for criticals, uncut thorns and plain rolls" do
    assert_equal "More than one 6, so thorns can't cut it", roll_reason(Roll.new(dice: [ 6, 6 ], thorns: [ 8 ]))
    assert_equal "Highest die 4, and no thorn cut it", roll_reason(Roll.new(dice: [ 4 ], thorns: [ 3 ]))
    assert_equal "Highest die 3", roll_reason(Roll.new(dice: [ 3, 1 ]))
    assert_equal "Messy, cut to disaster by 2 thorns", roll_reason(Roll.new(dice: [ 2, 5 ], thorns: [ 7, 8, 8 ]))
    assert_equal "Critical", roll_result_word(Roll.new(outcome: "perfect", critical: true))
  end

  test "a pool track has a segment per die, filled for what's left" do
    render "shared/pool_track", pool: Pool.new(starting_size: 6, size: 4, hidden: true)
    assert_select ".pool-track.pool-track--hidden[aria-label=?]", "4 of 6 dice left"
    assert_select ".pool-track__segment", 6
    assert_select ".pool-track__segment--full", 4
  end

  test "pips always say what they count" do
    render "shared/pips", kind: "spark", value: 1, max: 2
    assert_select ".pips--spark[role=img][aria-label=?]", "1 of 2 spark"
    assert_select ".pip", 2
    assert_select ".pip--full", 1

    render "shared/pips", kind: "suspense", value: 3
    assert_select ".pips--suspense[aria-label=?]", "3 suspense"
  end

  test "segmented toggles are labelled radios" do
    render "shared/segmented", name: "filter", legend: "Show", options: [ %w[ all Everything ], %w[ story Story ] ], checked: "all",
      input_data: { herb_set: "change->filter=$value" }
    assert_select "fieldset.segmented legend", "Show"
    assert_select "input[type=radio][name=filter][value=all][checked][data-herb-set=?]", "change->filter=$value"
    assert_select "input[type=radio][value=story]:not([checked])"
  end

  test "a stepper is a labelled number input with step buttons" do
    render "shared/stepper", text: "Thorns", name: "thorns", id: "roll_thorns", value: 1, max: 6
    assert_select "label[for=roll_thorns]", "Thorns"
    assert_select "input#roll_thorns[type=number][value='1'][max='6']"
    assert_select "button[aria-label=?]", "One more: Thorns"
  end

  test "a card wraps its block, dashed when empty" do
    render("shared/card", dashed: true) { "Mags joined" }
    assert_select "section.card.card--dashed", "Mags joined"
  end
end
