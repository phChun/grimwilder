// Run with: node --test test/javascript/dice.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { interpretRoll, actionRoll, rollPool } from "../../app/javascript/grimwild/dice.js"

// Shared with the Ruby rules (test/models/grimwild/dice_test.rb) so both agree.
const examples = JSON.parse(readFileSync(new URL("../dice_examples.json", import.meta.url)))

test("matches every shared example", () => {
  for (const { note, dice, thorns, result, critical, cuts, appliedCuts } of examples) {
    const r = interpretRoll(dice, thorns)
    assert.deepEqual({ result: r.result, critical: r.critical, cuts: r.cuts, appliedCuts: r.appliedCuts }, { result, critical, cuts, appliedCuts }, note)
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
