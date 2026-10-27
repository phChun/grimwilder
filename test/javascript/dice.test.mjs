// Run with: node --test test/javascript/dice.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { interpretRoll, actionRoll, rollPool, countAs, isTwist, talentRoll } from "../../app/javascript/grimwild/dice.js"

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

// Feeds exact faces: each entry is [face, sides].
function fixed(rolls) {
  const queue = [...rolls]
  return () => { const [face, sides] = queue.shift(); return (face - 0.5) / sides }
}

test("talentRoll: assists and Teamwork count an ally's 5 as a 6", () => {
  const r = talentRoll({ dice: 1, assists: 1, teamwork: true }, fixed([[6, 6], [5, 6]]))
  assert.deepEqual([r.dice, r.assistDice, r.counted, r.result, r.critical], [[6], [5], [6, 6], "perfect", true])
})

test("talentRoll: reckless counts your own 5s as 6s and 4s as 1s, not the assists'", () => {
  const r = talentRoll({ dice: 2, assists: 1, reckless: true }, fixed([[5, 6], [4, 6], [4, 6]]))
  assert.deepEqual([r.counted, r.result], [[6, 1, 4], "perfect"])
})

test("talentRoll: Panache removes thorns; removing them all rolls them as Panache dice", () => {
  const some = talentRoll({ dice: 1, thorns: 2, panache: 1 }, fixed([[3, 6], [8, 8]]))
  assert.deepEqual([some.thorns, some.boosts, some.result], [[8], [], "disaster"])

  const all = talentRoll({ dice: 1, thorns: 1, panache: 2 }, fixed([[3, 6], [7, 8]]))
  assert.deepEqual([all.removed, all.thorns, all.boosts, all.result], [1, [], [7], "messy"])
})

test("talentRoll: a spell with two 1s among your dice and thorns is a twist", () => {
  assert.equal(talentRoll({ dice: 2, thorns: 1, spell: true }, fixed([[1, 6], [5, 6], [1, 8]])).twist, true)
  assert.equal(talentRoll({ dice: 2, thorns: 1 }, fixed([[1, 6], [5, 6], [1, 8]])).twist, false)
})
