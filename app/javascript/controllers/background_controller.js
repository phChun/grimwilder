import { Controller } from "@hotwired/stimulus"
import { refillWises } from "grimwild/backgrounds"

// Picking a common background (pg. 49) fills its three wises. Switching to
// another replaces the wises the last one filled, but nothing the player
// wrote (refillWises).
export default class extends Controller {
  static targets = ["wise", "name"]
  static values = { wises: Object }

  connect() {
    this.previous = {}
    this.nameTargets.forEach((input) => { this.previous[input.dataset.index] = input.value.trim() })
  }

  fill(event) {
    const index = event.target.dataset.index
    const name = event.target.value.trim()
    const wises = this.wisesValue[name]
    const previousWises = this.wisesValue[this.previous[index]] || []
    this.previous[index] = name
    if (!wises) return

    const inputs = this.wiseTargets.filter((input) => input.dataset.index === index)
    refillWises(inputs.map((input) => input.value), previousWises, wises)
      .forEach((value, i) => { inputs[i].value = value })
  }
}
