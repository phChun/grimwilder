require "test_helper"

class Grimwild::DiceTest < ActiveSupport::TestCase
  # Shared with the JavaScript rules (test/javascript/dice.test.mjs) so both agree.
  EXAMPLES = JSON.parse(Rails.root.join("test/dice_examples.json").read)

  test "matches every shared example" do
    EXAMPLES.each do |example|
      result = Grimwild::Dice.interpret(example["dice"], example["thorns"])

      assert_equal example.values_at("result", "critical", "cuts", "appliedCuts"),
        [ result.result, result.critical, result.cuts, result.applied_cuts ], example["note"]
    end
  end

  test "needs at least one die" do
    assert_raises(ArgumentError) { Grimwild::Dice.interpret([]) }
  end

  test "rolls the requested dice" do
    result = Grimwild::Dice.roll(3, 2)

    assert_equal 3, result.dice.size
    assert_equal 2, result.thorns.size
    assert result.dice.all? { _1.in?(1..6) }
    assert result.thorns.all? { _1.in?(1..8) }
  end
end
