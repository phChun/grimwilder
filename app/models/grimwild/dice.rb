# Action and defense rolls (pg. 11–16), for rolls the server makes so the
# table's log can be trusted. Mirrors interpretRoll in
# app/javascript/grimwild/dice.js; both are tested against the same examples
# (test/dice_examples.json).
#
# The highest d6 sets the result. Each thorn (d8) showing 7 or 8 cuts it one
# step, down to disaster. More than one 6 is a critical, which thorns can't cut.
#
# Talents bend that: Panache's dice (d8s, in place of removed thorns) each
# raise the result a step on a 7 or 8, up to perfect; a reckless roll (Into
# the Fray, Audacity…) counts 5s as 6s and 4s as 1s, and Teamwork counts an
# assist's 5s as 6s (count_as, before interpret); a spell with two or more 1s,
# thorns included, triggers a magical twist (twist?).
module Grimwild::Dice
  RESULTS = %w[ perfect messy grim disaster ].freeze
  COUNTS_AS = { "reckless" => { 5 => 6, 4 => 1 }, "teamwork" => { 5 => 6 } }.freeze

  Result = Data.define(:dice, :thorns, :result, :critical, :highest, :cuts, :applied_cuts, :boosts, :applied_boosts) do
    alias_method :critical?, :critical
  end

  extend self

  def roll(dice_count, thorn_count, random: Random)
    dice = Array.new(dice_count) { random.rand(1..6) }
    thorns = Array.new(thorn_count) { random.rand(1..8) }
    interpret(dice, thorns)
  end

  def interpret(dice, thorns = [], boosts: [])
    raise ArgumentError, "An action roll needs at least 1d" if dice.empty?

    highest = dice.max
    cuts = thorns.count { |thorn| thorn >= 7 }

    if dice.count(6) > 1
      Result.new(dice:, thorns:, result: "perfect", critical: true, highest:, cuts:, applied_cuts: 0, boosts:, applied_boosts: 0)
    else
      base = RESULTS.index(base_result(highest))
      cut = [ base + cuts, RESULTS.size - 1 ].min
      index = [ cut - boosts.count { |boost| boost >= 7 }, 0 ].max
      Result.new(dice:, thorns:, result: RESULTS[index], critical: false, highest:, cuts:, applied_cuts: cut - base, boosts:, applied_boosts: cut - index)
    end
  end

  # What dice count as under a rule ("reckless", "teamwork"); nil leaves them.
  def count_as(dice, rule)
    rule ? dice.map { COUNTS_AS.fetch(rule).fetch(_1, _1) } : dice
  end

  # Two or more 1s among the d6s (as counted) and thorns: a magical twist.
  def twist?(dice, thorns = [])
    (dice + thorns).count(1) >= 2
  end

  private
    def base_result(highest)
      if highest == 6 then "perfect"
      elsif highest >= 4 then "messy"
      else "grim"
      end
    end
end
