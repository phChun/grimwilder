import { Controller } from "@hotwired/stimulus"

// Keeps a stat card's "Roll 3d + 1t" button in step with its setup: the dice
// and thorns steppers, spark and panache spent, talents and assists ticked
// (with each assist's own talents), and the talents that always apply.
// Defense-only talents don't count toward it, since the button rolls an
// action. The server rolls.
export default class extends Controller {
  static targets = ["label", "auto", "allyAuto"]

  update() {
    const form = this.element
    const number = (name) => Number(form.elements[name]?.value) || 0
    const spark = Number(form.querySelector("input[name=spark]:checked")?.value) || 0
    const panache = Number(form.querySelector("input[name=panache]:checked")?.value) || 0
    const forAction = (talent) => talent.dataset.defenseOnly !== "true"
    const diceOf = (talents) => talents.filter(forAction).reduce((sum, talent) => sum + (Number(talent.dataset.dice) || 0), 0)
    const allies = [...form.querySelectorAll("input[name='assists[]']:checked")].map((input) => input.value)
    const allyTalents = [...form.querySelectorAll("input[data-ally]:checked"), ...this.allyAutoTargets]
      .filter((talent) => allies.includes(talent.dataset.ally))
    const assists = allies.length + diceOf(allyTalents)
    const talents = [...form.querySelectorAll("input[name='bonuses[]']:checked"), ...this.autoTargets].filter(forAction)
    const leftOut = Math.max(0, ...talents.map((talent) => Number(talent.dataset.ignoreThorns) || 0))
    const dice = number("dice") + spark + assists + diceOf(talents)
    const before = Math.max(0, number("total_thorns") - leftOut)
    const thorns = Math.max(0, before - panache)
    const panacheDice = panache > 0 && thorns === 0 ? Math.min(panache, before) : 0

    this.labelTarget.textContent = `Roll ${dice}d${thorns > 0 ? ` + ${thorns}t` : ""}${panacheDice > 0 ? ` + ${panacheDice} panache` : ""}`
  }
}
