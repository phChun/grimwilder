import { Controller } from "@hotwired/stimulus"

// Copies what's in its source box (the GM's "Copy for an AI" Markdown, which
// they may have edited) and says so. Without clipboard access, it selects the
// text so the GM can copy it by hand.
export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.say("Copied.")
    } catch {
      this.sourceTarget.select()
      this.say("Selected: press Ctrl+C or ⌘C to copy.")
    }
  }

  say(message) {
    this.statusTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.statusTarget.textContent = "" }, 3000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
