import { Controller } from "@hotwired/stimulus"

// A running clock ("1:12:05") for the GM table's session and scene. The server
// says how many seconds had run when it rendered (elapsed), and this counts on
// from there, so the viewer's own clock being off doesn't matter. A morph
// refresh brings a new elapsed, which starts the count again from it.
export default class extends Controller {
  static values = { elapsed: Number }

  connect() {
    this.timer = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  elapsedValueChanged() {
    this.startedAt = performance.now()
    this.render()
  }

  render() {
    const seconds = this.elapsedValue + Math.floor((performance.now() - this.startedAt) / 1000)
    this.element.textContent = clockText(seconds)
  }
}

// 754 -> "12:34", 4325 -> "1:12:05".
export function clockText(total) {
  const seconds = Math.max(0, total)
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const pad = (n) => String(n).padStart(2, "0")
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(seconds % 60)}` : `${minutes}:${pad(seconds % 60)}`
}
