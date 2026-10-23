import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"
import { actionRoll } from "grimwild/dice"

// Rolls the dice for the action roller. The stat/thorns/mode inputs live in
// herb:state on the template (roll/show); this controller reads them, rolls,
// draws the dice into the tray, and writes `outcome` + `critical` back so the
// template can show the matching result text.
export default class extends Controller {
  static targets = ["tray"]

  connect() {
    useState(this)
  }

  roll() {
    const stat = this.state.get("stat")
    const thorns = this.state.get("thorns")
    const result = actionRoll(stat, thorns)

    this.drawTray(result)

    this.state.set({ outcome: result.result, critical: result.critical })
  }

  clear() {
    this.trayTarget.replaceChildren()
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

    // The dice on one line, the thorns (if any) on the next.
    this.trayTarget.replaceChildren(this.row("Dice", d6s), ...(d8s.length ? [this.row("Thorns", d8s)] : []))
  }

  row(label, dice) {
    const el = document.createElement("div")
    el.className = "tray__row"
    el.setAttribute("role", "group")
    el.setAttribute("aria-label", label)
    el.append(...dice)
    return el
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
}
