import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"
import { actionRoll } from "grimwild/dice"

// Rolls the dice for the action roller. The stat/thorns/mode inputs live in
// herb:state on the template (roll/show); this controller reads them, rolls,
// draws the dice into the tray, and writes `outcome` + `critical` back so the
// template can show the matching result text.
export default class extends Controller {
  static targets = ["tray", "summary"]

  connect() {
    useState(this)
  }

  roll() {
    const stat = this.state.get("stat")
    const thorns = this.state.get("thorns")
    const result = actionRoll(stat, thorns)

    this.drawTray(result)
    this.summaryTarget.textContent = this.summarize(result)

    this.state.set({ outcome: result.result, critical: result.critical })
  }

  clear() {
    this.trayTarget.replaceChildren()
    this.summaryTarget.textContent = ""
    this.state.set({ outcome: "", critical: false })
  }

  drawTray({ dice, thorns, highest }) {
    let markedHighest = false
    const d6s = dice.map((value) => {
      const top = value === highest && (!markedHighest || value === 6)
      if (top) markedHighest = true
      return this.die(value, "d6", top ? "die--top" : null)
    })
    const d8s = thorns.map((value) => this.die(value, "d8", value >= 7 ? "die--cut" : null))

    this.trayTarget.replaceChildren(...d6s, ...d8s)
  }

  // Matches shared/_die: a d6 carries its own result's tier for when it's lit.
  die(value, kind, modifier) {
    const el = document.createElement("span")
    const tier = kind === "d6" ? (value === 6 ? "perfect" : value >= 4 ? "messy" : "grim") : null
    el.className = ["die", `die--${kind}`, tier && `die--${tier}`, modifier].filter(Boolean).join(" ")
    el.textContent = value
    el.setAttribute("aria-label", `${kind === "d8" ? "thorn" : kind} showing ${value}`)
    el.style.setProperty("--delay", `${Math.random() * 120}ms`)
    return el
  }

  summarize({ highest, cuts, appliedCuts, critical }) {
    if (critical) return `Multiple 6s — critical, thorns ignored${cuts ? ` (${cuts} cut${cuts > 1 ? "s" : ""} ignored)` : ""}.`
    const parts = [`Highest d6: ${highest}`]
    if (cuts) parts.push(`${cuts} cut${cuts > 1 ? "s" : ""}${appliedCuts < cuts ? ` (${appliedCuts} applied)` : ""}`)
    return parts.join(" · ")
  }
}
