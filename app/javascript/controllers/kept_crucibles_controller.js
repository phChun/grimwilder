import { Controller } from "@hotwired/stimulus"

// The campaign page's "Kept crucibles": the words kept from crucible rolls,
// which crucible_controller.js saves per crucible in this browser's
// localStorage. Stays hidden when there are none (or storage is blocked).
export default class extends Controller {
  static targets = ["line"]

  connect() {
    const kept = this.read().slice(0, 4)
    if (kept.length === 0) return

    this.lineTarget.textContent = kept.join(" · ")
    this.element.hidden = false
  }

  read() {
    try {
      const lines = []
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i)
        if (!/^grimwilder:crucible:.+:kept$/.test(key)) continue
        const list = JSON.parse(localStorage.getItem(key) || "[]")
        if (Array.isArray(list)) lines.push(...list.slice(0, 2))
      }
      return lines.map((line) => String(line).replaceAll(" + ", " "))
    } catch {
      return []
    }
  }
}
