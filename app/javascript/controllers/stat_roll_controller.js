import { Controller } from "@hotwired/stimulus"

// Keeps a stat card's "Roll 3d + 1t" button in step with its setup: the dice
// and thorns steppers, spark spent and assists ticked. The server rolls.
export default class extends Controller {
  static targets = ["label"]

  update() {
    const form = this.element
    const number = (name) => Number(form.elements[name]?.value) || 0
    const spark = Number(form.querySelector("input[name=spark]:checked")?.value) || 0
    const assists = form.querySelectorAll("input[name='assists[]']:checked").length
    const dice = number("dice") + spark + assists
    const thorns = number("total_thorns")

    this.labelTarget.textContent = `Roll ${dice}d${thorns > 0 ? ` + ${thorns}t` : ""}`
  }
}
