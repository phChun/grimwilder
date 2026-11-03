import { test } from "node:test"
import assert from "node:assert/strict"

// clock_controller.js imports Stimulus, which Node can't resolve; stub it.
import { register } from "node:module"
register("data:text/javascript," + encodeURIComponent(`
  export async function resolve(specifier, context, next) {
    if (specifier === "@hotwired/stimulus") return { url: "data:text/javascript,export class Controller {}", shortCircuit: true }
    return next(specifier, context)
  }
`))
const { clockText } = await import("../../app/javascript/controllers/clock_controller.js")

test("the running clock reads minutes and seconds, then hours", () => {
  assert.equal(clockText(0), "0:00")
  assert.equal(clockText(754), "12:34")
  assert.equal(clockText(3600), "1:00:00")
  assert.equal(clockText(4325), "1:12:05")
  assert.equal(clockText(-5), "0:00", "never below zero")
})
