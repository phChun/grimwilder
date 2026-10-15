// Run with: node --test test/javascript/dice.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { interpretRoll, actionRoll, rollPool } from "../../app/javascript/grimwild/dice.js"

test("highest d6 sets the base result", () => {
  assert.equal(interpretRoll([2, 6]).result, "perfect")
  assert.equal(interpretRoll([3, 5]).result, "messy")
  assert.equal(interpretRoll([4]).result, "messy")
  assert.equal(interpretRoll([1, 3, 2]).result, "grim")
})

test("each 7 or 8 thorn cuts one step", () => {
  assert.equal(interpretRoll([2, 6], [7]).result, "messy") // book example, pg. 122
  assert.equal(interpretRoll([3, 4, 2], [7, 8]).result, "disaster") // book example, pg. 122
  assert.equal(interpretRoll([6], [1, 6]).result, "perfect")
  assert.equal(interpretRoll([2], [8]).result, "disaster")
})

test("cuts stop at disaster", () => {
  const r = interpretRoll([1], [7, 8, 8])
  assert.equal(r.result, "disaster")
  assert.equal(r.cuts, 3)
  assert.equal(r.appliedCuts, 1)
})

test("multiple 6s are a critical that thorns can't cut", () => {
  const r = interpretRoll([6, 6, 1], [7, 8])
  assert.equal(r.result, "perfect")
  assert.equal(r.critical, true)
})

test("a single 6 is not a critical", () => {
  assert.equal(interpretRoll([6, 5]).critical, false)
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
