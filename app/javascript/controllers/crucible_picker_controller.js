import { Controller } from "@hotwired/stimulus"

// Picks which crucible the GM table's "crucible" frame shows (the frame loads
// /crucibles/:key?embed=1), and keeps the last three used as "Recent" chips,
// per browser, in localStorage.
export default class extends Controller {
  static targets = ["select", "frame", "recent", "current"]
  static values = { url: String } // with __key__ where the crucible's key goes

  connect() {
    this.recent = this.loadRecent().filter((key) => this.option(key))
    const last = this.recent[0]
    if (last && last !== this.selectTarget.value) {
      this.selectTarget.value = last
      this.load(last)
    }
    this.render()
  }

  pick() {
    this.load(this.selectTarget.value)
    this.remember(this.selectTarget.value)
  }

  choose(event) {
    this.selectTarget.value = event.currentTarget.dataset.key
    this.pick()
  }

  load(key) {
    this.frameTarget.src = this.urlValue.replace("__key__", encodeURIComponent(key))
    if (this.hasCurrentTarget) this.currentTarget.textContent = this.option(key)?.textContent ?? ""
  }

  remember(key) {
    this.recent = [key, ...this.recent.filter((other) => other !== key)].slice(0, 3)
    try {
      localStorage.setItem("grimwilder:crucibles:recent", JSON.stringify(this.recent))
    } catch {
      // Storage blocked: the chips just last for this page view.
    }
    this.render()
  }

  render() {
    const chips = this.recent.map((key) => {
      const chip = document.createElement("button")
      chip.type = "button"
      chip.className = "chip chip--small"
      chip.textContent = this.option(key).textContent
      chip.dataset.key = key
      chip.dataset.action = "crucible-picker#choose"
      return chip
    })
    const label = document.createElement("span")
    label.className = "crucible-picker__label"
    label.textContent = "Recent:"

    this.recentTarget.replaceChildren(label, ...chips)
    this.recentTarget.hidden = chips.length === 0
  }

  option(key) {
    return [...this.selectTarget.options].find((option) => option.value === key)
  }

  loadRecent() {
    try {
      return JSON.parse(localStorage.getItem("grimwilder:crucibles:recent")) || []
    } catch {
      return []
    }
  }
}
