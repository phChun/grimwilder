import { Controller } from "@hotwired/stimulus"

// The − and + of shared/_stepper. It steps the real number input and fires
// the events a typed change would, so forms and herb bindings see it.
export default class extends Controller {
  static targets = ["input"]

  down() { this.step(-1) }
  up() { this.step(1) }

  step(direction) {
    const input = this.inputTarget
    direction < 0 ? input.stepDown() : input.stepUp()
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
