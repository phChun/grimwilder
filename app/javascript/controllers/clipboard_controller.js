import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"

// Copies `data-clipboard-text-value` and flips the template's `copied`
// herb:state so it can say "Copied" for a moment.
export default class extends Controller {
  static values = { text: String }

  connect() {
    useState(this)
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.state.set({ copied: true })
      clearTimeout(this.timer)
      this.timer = setTimeout(() => this.state.set({ copied: false }), 2000)
    } catch {
      window.prompt("Copy this link:", this.textValue)
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
