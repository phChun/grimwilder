// Run with: node --test test/javascript/dice.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { interpretRoll, actionRoll, rollPool, countAs, isTwist } from "../../app/javascript/grimwild/dice.js"

// Shared with the Ruby rules (test/models/grimwild/dice_test.rb) so both agree.
const examples = JSON.parse(readFileSync(new URL("../dice_examples.json", import.meta.url)))

test("matches every shared example", () => {
  for (const example of examples) {
    const { note, thorns, result, critical, cuts, appliedCuts } = example
    const dice = countAs(example.dice, example.countAs)
    const r = interpretRoll(dice, thorns, { boosts: example.boosts ?? [] })
    assert.deepEqual({ result: r.result, critical: r.critical, cuts: r.cuts, appliedCuts: r.appliedCuts }, { result, critical, cuts, appliedCuts }, note)
    if ("appliedBoosts" in example) assert.equal(r.appliedBoosts, example.appliedBoosts, note)
    if ("twist" in example) assert.equal(isTwist(dice, thorns), example.twist, note)
  }
})

test("needs at least one die", () => {
  assert.throws(() => interpretRoll([]))
})

test("actionRoll rolls the requested dice", () => {
  const r = actionRoll(3, 2)
  assert.equal(r.dice.length, 3)
  assert.equal(r.thorns.length, 2)
  assert.ok(r.dice.every((d) => d >= 1 && d <= 6))
  assert.ok(r.thorns.every((t) => t >= 1 && t <= 8))
})

test("rollPool drops 1–3", () => {
  const seq = [0.0, 0.5, 0.99, 0.4] // -> 1, 4, 6, 3
  let i = 0
  const r = rollPool(4, () => seq[i++])
  assert.deepEqual(r.dice, [1, 4, 6, 3])
  assert.equal(r.remaining, 2)
  assert.equal(r.dropped, 2)
})
