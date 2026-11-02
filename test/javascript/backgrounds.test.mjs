// Run with: node --test test/javascript/backgrounds.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { refillWises } from "../../app/javascript/grimwild/backgrounds.js"

const sailor = ["Ships", "Weather", "Knots"]
const scholar = ["Books", "History", "Languages"]

test("fills empty boxes", () => {
  assert.deepEqual(refillWises(["", "", ""], [], sailor), sailor)
})

test("switching backgrounds replaces the old one's wises", () => {
  assert.deepEqual(refillWises(sailor, sailor, scholar), scholar)
})

test("keeps what the player wrote, matching the old wises loosely", () => {
  assert.deepEqual(refillWises(["Ships", "Smuggling routes", " weather "], sailor, scholar), ["Books", "Smuggling routes", "Languages"])
})
