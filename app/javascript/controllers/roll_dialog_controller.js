import { Controller } from "@hotwired/stimulus"

// A stat card's roll setup, in a modal (characters/_roll_form): the card's
// Roll button opens it; Escape, its ✕ or a click outside close it. A talent's
// Cast button links to the sheet with the setup ready (open: true), so it
// opens on load. Rolling closes it before the page refreshes: a morph only
// strips the open attribute, which hides a modal dialog without closing it,
// and the page would stay inert (nothing clickable, the roll toast included).
export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue && !this.dialogTarget.open) this.open()
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  submitted(event) {
    if (event.detail.success) this.close()
  }

  disconnect() {
    this.close()
  }

  // A click on the backdrop lands on the dialog itself, outside its box.
  backdrop(event) {
    if (event.target !== this.dialogTarget) return
    const box = this.dialogTarget.getBoundingClientRect()
    const inside = event.clientX >= box.left && event.clientX <= box.right && event.clientY >= box.top && event.clientY <= box.bottom
    if (!inside) this.close()
  }
}
