import { Controller } from "@hotwired/stimulus"

// Keeps a stat card's "Roll 3d + 1t" button in step with its setup: the dice
// and thorns steppers, spark spent, talents and assists ticked, and the
// talents that always apply. Defense-only talents don't count toward it,
// since the button rolls an action. The server rolls.
export default class extends Controller {
  static targets = ["label", "auto"]

  update() {
    const form = this.element
    const number = (name) => Number(form.elements[name]?.value) || 0
    const spark = Number(form.querySelector("input[name=spark]:checked")?.value) || 0
    const assists = form.querySelectorAll("input[name='assists[]']:checked").length
    const talents = [...form.querySelectorAll("input[name='bonuses[]']:checked"), ...this.autoTargets]
      .filter((talent) => talent.dataset.defenseOnly !== "true")
    const talentDice = talents.reduce((sum, talent) => sum + (Number(talent.dataset.dice) || 0), 0)
    const leftOut = Math.max(0, ...talents.map((talent) => Number(talent.dataset.ignoreThorns) || 0))
    const dice = number("dice") + spark + assists + talentDice
    const thorns = Math.max(0, number("total_thorns") - leftOut)

    this.labelTarget.textContent = `Roll ${dice}d${thorns > 0 ? ` + ${thorns}t` : ""}`
  }
}
