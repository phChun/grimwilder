import { Controller } from "@hotwired/stimulus"

// The ✕ in a floating <details> panel (shared/_close_button): closes the menu
// it's in and puts focus back on the menu's button.
export default class extends Controller {
  close() {
    const details = this.element.closest("details")
    if (!details) return
    details.open = false
    details.querySelector(":scope > summary")?.focus()
  }
}
