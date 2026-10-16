# Action and defense rolls (pg. 10–15), for rolls the server makes so the
# table's log can be trusted. Mirrors interpretRoll in
# app/javascript/grimwild/dice.js; both are tested against the same examples
# (test/dice_examples.json).
#
# The highest d6 sets the result. Each thorn (d8) showing 7 or 8 cuts it one
# step, down to disaster. More than one 6 is a critical, which thorns can't cut.
module Grimwild::Dice
  RESULTS = %w[ perfect messy grim disaster ].freeze

  Result = Data.define(:dice, :thorns, :result, :critical, :highest, :cuts, :applied_cuts) do
    alias_method :critical?, :critical
  end

  extend self

  def roll(dice_count, thorn_count, random: Random)
    dice = Array.new(dice_count) { random.rand(1..6) }
    thorns = Array.new(thorn_count) { random.rand(1..8) }
    interpret(dice, thorns)
  end

  def interpret(dice, thorns = [])
    raise ArgumentError, "An action roll needs at least 1d" if dice.empty?

    highest = dice.max
    cuts = thorns.count { |thorn| thorn >= 7 }

    if dice.count(6) > 1
      Result.new(dice:, thorns:, result: "perfect", critical: true, highest:, cuts:, applied_cuts: 0)
    else
      base = RESULTS.index(base_result(highest))
      index = [ base + cuts, RESULTS.size - 1 ].min
      Result.new(dice:, thorns:, result: RESULTS[index], critical: false, highest:, cuts:, applied_cuts: index - base)
    end
  end

  private
    def base_result(highest)
      if highest == 6 then "perfect"
      elsif highest >= 4 then "messy"
      else "grim"
      end
    end
end
