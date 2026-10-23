import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The "Kept crucibles" card (campaigns/_kept_crucibles): the words kept from
// crucible rolls, which crucible_controller.js saves per crucible in this
// browser's localStorage, listed under each crucible's name in the
// crucibles' own order (crucibles value, by kind). Stays hidden when there
// are none (or storage is blocked). Clear empties every crucible's kept
// list in this browser, after asking.
export default class extends Controller {
  static targets = ["list"]
  static values = { crucibles: Array }

  connect() {
    this.refresh()
  }

  // Also when a crucible on this page keeps a line (crucible:kept).
  refresh() {
    const groups = this.read()
    this.listTarget.replaceChildren(...groups.map(({ name, lines }) => {
      const group = document.createElement("div")
      group.className = "kept-group"
      const title = document.createElement("p")
      title.className = "kept-group__name"
      title.textContent = name
      const line = document.createElement("p")
      line.className = "kept-line"
      line.textContent = lines.join(" · ")
      group.append(title, line)
      return group
    }))
    this.element.hidden = groups.length === 0
  }

  async clear(event) {
    const message = "Clear every kept crucible line on this device?"
    const confirm = Turbo.config.forms.confirm
    const sure = confirm ? await confirm(message, null, event.currentTarget) : window.confirm(message)
    if (!sure) return

    try {
      this.keys().forEach((key) => localStorage.removeItem(key))
    } catch {
      // Storage blocked: there was nothing kept to clear.
    }
    this.element.hidden = true
  }

  // [{ name, lines }], the two most recent lines of each crucible with any.
  read() {
    try {
      const known = this.cruciblesValue.map(({ key }) => key)
      const keys = this.keys()
        .map((storageKey) => ({ storageKey, key: storageKey.split(":")[2] }))
        .sort((a, b) => this.rank(known, a.key) - this.rank(known, b.key))

      return keys.flatMap(({ storageKey, key }) => {
        const list = JSON.parse(localStorage.getItem(storageKey) || "[]")
        if (!Array.isArray(list) || list.length === 0) return []
        const name = this.cruciblesValue.find((crucible) => crucible.key === key)?.name || key
        return [{ name, lines: list.slice(0, 2).map((line) => String(line).replaceAll(" + ", " ")) }]
      })
    } catch {
      return []
    }
  }

  rank(known, key) {
    const index = known.indexOf(key)
    return index === -1 ? known.length : index
  }

  keys() {
    const keys = []
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (/^grimwilder:crucible:.+:kept$/.test(key)) keys.push(key)
    }
    return keys
  }
}
