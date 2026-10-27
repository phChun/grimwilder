import { Controller } from "@hotwired/stimulus"

// Picking a common background (pg. 49) fills its three wises, but only into
// empty boxes, so nothing the player wrote is overwritten.
export default class extends Controller {
  static targets = ["wise"]
  static values = { wises: Object }

  fill(event) {
    const index = event.target.dataset.index
    const wises = this.wisesValue[event.target.value.trim()]
    if (!wises) return

    this.wiseTargets
      .filter((input) => input.dataset.index === index)
      .forEach((input, i) => { if (!input.value.trim()) input.value = wises[i] || "" })
  }
}
