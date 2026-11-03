import { test } from "node:test"
import assert from "node:assert/strict"
import { register } from "node:module"

// selects_controller.js imports Stimulus, which Node can't resolve; stub it.
register("data:text/javascript," + encodeURIComponent(`
  export async function resolve(specifier, context, next) {
    if (specifier === "@hotwired/stimulus") return { url: "data:text/javascript,export class Controller {}", shortCircuit: true }
    return next(specifier, context)
  }
`))
const { matches } = await import("../../app/javascript/controllers/selects_controller.js")

test("a dropdown's search finds every word, ignoring case, accents and underscores", () => {
  assert.ok(matches("America/New_York", "new york"))
  assert.ok(matches("Fighter (Weapon Mastery)", "mastery fight"))
  assert.ok(matches("Café Noir", "cafe"))
  assert.ok(matches("Anything", ""), "an empty search shows everything")
  assert.ok(!matches("Rogue (Expertise)", "wizard"))
})
